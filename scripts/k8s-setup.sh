#!/usr/bin/env bash
# =============================================================================
# k8s-setup.sh
# Setup completo do ambiente Kubernetes local (minikube) para a devops-ai-platform.
#
# Sequência de etapas:
#   1. Verificar pré-requisitos — minikube, kubectl, terraform, docker, daemon
#   2. Iniciar minikube — start com --driver=docker (idempotente se já rodando)
#      e habilitar addon ingress, aguardando controller Ready
#   3. Configurar contexto Docker — eval $(minikube docker-env)
#   4. Buildar imagens — docker compose build; validar api-gateway e worker-service
#   5. Terraform init — inicializar backend e providers
#   6. Terraform apply — provisionar toda a infra K8s via IaC
#   7. Aguardar pods Ready — rollout status de api-gateway e worker-service
#   8. Validar via curl — GET /health via Ingress nginx retorna HTTP 200
#
# Uso:
#   ./scripts/k8s-setup.sh
#
# REQUISITOS OBRIGATÓRIOS:
#   - minikube v1.32+   https://minikube.sigs.k8s.io/docs/start/
#   - kubectl v1.29+    https://kubernetes.io/docs/tasks/tools/
#   - terraform v1.7+   https://developer.hashicorp.com/terraform/downloads
#   - Docker Desktop com integração WSL2 habilitada
#   - bash >= 4.0
#
# NOTA SOBRE DOCKER DESKTOP NO WINDOWS:
#   Este script requer WSL2 com Docker Desktop integration habilitada em
#   Docker Desktop → Settings → Resources → WSL Integration.
#   O contexto Docker é alterado para o daemon do minikube via
#   `eval $(minikube docker-env)` — essa alteração é válida apenas na
#   sessão corrente do shell.
#
# IDEMPOTÊNCIA:
#   O script é seguro para re-execução. Se o minikube já estiver rodando,
#   o start é pulado. Se o terraform já estiver aplicado, o apply converge
#   sem alterações (zero drift). Se as imagens já existirem no daemon
#   minikube, o build sobrescreve com a versão mais recente.
#
# IMPORTANTE:
#   Este script foi validado estaticamente (bash -n). A execução real requer
#   o ambiente WSL2 com todas as ferramentas instaladas e Docker Desktop
#   operacional. Ao final do setup, adicione ao /etc/hosts do WSL2:
#     <minikube ip>  api-gateway.local
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Localização dinâmica da raiz do repositório
# O script funciona independentemente de onde é chamado.
# ---------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Configuração
# ---------------------------------------------------------------------------
readonly COMPOSE_FILE="${REPO_ROOT}/infra/docker/docker-compose.yml"
readonly TERRAFORM_DIR="${REPO_ROOT}/infra/terraform"
readonly K8S_NAMESPACE="devops-ai"
readonly IMAGE_TAG="${IMAGE_TAG:-latest}"
readonly INGRESS_WAIT_TIMEOUT=90
readonly POD_READY_TIMEOUT=120
readonly CURL_TIMEOUT_SECONDS=10

# ---------------------------------------------------------------------------
# Cores para output (desativadas quando não é terminal)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    BOLD=''
    RESET=''
fi

# ---------------------------------------------------------------------------
# Funções de log
# ---------------------------------------------------------------------------

log_step() {
    local step="$1"
    local msg="$2"
    echo -e "\n${CYAN}${BOLD}[${SCRIPT_NAME}] ETAPA ${step}:${RESET} ${msg}"
}

log_info() {
    echo -e "${YELLOW}[${SCRIPT_NAME}]${RESET} $*"
}

log_ok() {
    echo -e "${GREEN}[${SCRIPT_NAME}] OK:${RESET} $*"
}

log_error() {
    echo -e "${RED}[${SCRIPT_NAME}] ERRO:${RESET} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[${SCRIPT_NAME}] AVISO:${RESET} $*"
}

log_summary_ok() {
    echo -e "\n${GREEN}${BOLD}[${SCRIPT_NAME}] SETUP CONCLUIDO — todas as 8 etapas finalizadas com sucesso.${RESET}"
}

log_summary_fail() {
    local step="$1"
    local reason="$2"
    echo -e "\n${RED}${BOLD}[${SCRIPT_NAME}] SETUP FALHOU na etapa ${step}: ${reason}${RESET}" >&2
}

# ---------------------------------------------------------------------------
# Cleanup: diagnóstico em caso de falha
# ---------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_warn "Setup encerrado com falha (exit code ${exit_code}). Executando diagnóstico..."
        log_info "Estado dos pods no namespace ${K8S_NAMESPACE}:"
        kubectl get pods -n "${K8S_NAMESPACE}" 2>/dev/null || true
        log_info "Para diagnóstico detalhado execute:"
        log_info "  kubectl describe pod -n ${K8S_NAMESPACE}"
        log_info "  kubectl logs -n ${K8S_NAMESPACE} -l app=api-gateway --tail=50"
        log_info "  kubectl logs -n ${K8S_NAMESPACE} -l app=worker-service --tail=50"
    fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# ETAPA 1 — Verificar pré-requisitos
# ---------------------------------------------------------------------------
step1_check_prerequisites() {
    log_step 1 "Verificar pré-requisitos"
    log_info "Verificando ferramentas necessárias..."

    local prereq_failed=0

    # minikube
    if ! command -v minikube &>/dev/null; then
        log_error "minikube não encontrado no PATH."
        log_error "  Instale em: https://minikube.sigs.k8s.io/docs/start/"
        prereq_failed=1
    else
        log_info "  minikube:   $(minikube version --short 2>/dev/null || minikube version | head -1)"
    fi

    # kubectl
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl não encontrado no PATH."
        log_error "  Instale em: https://kubernetes.io/docs/tasks/tools/"
        prereq_failed=1
    else
        log_info "  kubectl:    $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"
    fi

    # terraform
    if ! command -v terraform &>/dev/null; then
        log_error "terraform não encontrado no PATH."
        log_error "  Instale em: https://developer.hashicorp.com/terraform/downloads"
        prereq_failed=1
    else
        log_info "  terraform:  $(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)"
    fi

    # docker
    if ! command -v docker &>/dev/null; then
        log_error "docker não encontrado no PATH."
        log_error "  Instale em: https://docs.docker.com/engine/install/"
        prereq_failed=1
    else
        log_info "  docker:     $(docker --version)"
    fi

    # Sair já se algum binário estiver faltando (docker info vai falhar)
    if [[ ${prereq_failed} -eq 1 ]]; then
        log_summary_fail 1 "uma ou mais ferramentas obrigatórias não foram encontradas."
        exit 1
    fi

    # Verificar daemon Docker em execução
    log_info "Verificando se o daemon Docker está acessível..."
    if ! docker info &>/dev/null; then
        log_error "docker info falhou — daemon Docker não está rodando ou não está acessível."
        log_error "Verifique se o Docker Desktop está aberto e a integração WSL2 está habilitada:"
        log_error "  Docker Desktop → Settings → Resources → WSL Integration"
        log_summary_fail 1 "daemon Docker não está rodando."
        exit 1
    fi

    # Verificar arquivo docker-compose.yml
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        log_error "Arquivo não encontrado: ${COMPOSE_FILE}"
        log_error "Certifique-se de que a feature init foi concluída e o arquivo existe."
        log_summary_fail 1 "docker-compose.yml não encontrado."
        exit 1
    fi

    # Verificar diretório terraform
    if [[ ! -d "${TERRAFORM_DIR}" ]]; then
        log_error "Diretório não encontrado: ${TERRAFORM_DIR}"
        log_error "Certifique-se de que as tasks T-02 e T-03 foram concluídas."
        log_summary_fail 1 "diretório infra/terraform não encontrado."
        exit 1
    fi

    log_ok "Todos os pré-requisitos satisfeitos."
    log_info "  Compose file:    ${COMPOSE_FILE}"
    log_info "  Terraform dir:   ${TERRAFORM_DIR}"
    log_info "  Namespace K8s:   ${K8S_NAMESPACE}"
    log_info "  Image tag:       ${IMAGE_TAG}"
}

# ---------------------------------------------------------------------------
# ETAPA 2 — Iniciar minikube
# ---------------------------------------------------------------------------
step2_start_minikube() {
    log_step 2 "Iniciar minikube"

    # Idempotência: verificar se minikube já está rodando
    local minikube_status
    minikube_status=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")

    if [[ "${minikube_status}" == "Running" ]]; then
        log_info "minikube já está rodando — pulando start (idempotente)."
    else
        log_info "minikube não está rodando (status: ${minikube_status}). Iniciando com --driver=docker..."
        if ! minikube start --driver=docker; then
            log_error "minikube start --driver=docker falhou."
            log_error "Verifique se o Docker Desktop está rodando e a integração WSL2 está ativa."
            log_error "Alternativa: tente --driver=virtualbox se --driver=docker não funcionar."
            log_summary_fail 2 "minikube start falhou."
            exit 1
        fi
        log_ok "minikube iniciado com sucesso."
    fi

    # Habilitar addon ingress (idempotente — não falha se já habilitado)
    log_info "Habilitando addon ingress-nginx..."
    minikube addons enable ingress || true

    # Aguardar ingress-nginx-controller ficar Ready
    log_info "Aguardando pod ingress-nginx-controller ficar Ready (timeout: ${INGRESS_WAIT_TIMEOUT}s)..."
    if ! kubectl wait \
            --for=condition=Ready \
            pod \
            -l app.kubernetes.io/name=ingress-nginx \
            -n ingress-nginx \
            --timeout="${INGRESS_WAIT_TIMEOUT}s"; then
        log_error "ingress-nginx-controller não ficou Ready em ${INGRESS_WAIT_TIMEOUT}s."
        log_error "Diagnóstico:"
        kubectl get pods -n ingress-nginx 2>/dev/null || true
        kubectl describe pod -n ingress-nginx 2>/dev/null || true
        log_summary_fail 2 "ingress-nginx-controller não ficou Ready no timeout."
        exit 1
    fi

    log_ok "Etapa 2 concluída — minikube rodando e ingress-nginx-controller Ready."
    log_info "  minikube IP: $(minikube ip 2>/dev/null || echo 'indisponível')"
}

# ---------------------------------------------------------------------------
# ETAPA 3 — Configurar contexto Docker
# ---------------------------------------------------------------------------
step3_configure_docker_context() {
    log_step 3 "Configurar contexto Docker para daemon minikube"

    log_info "Executando: eval \$(minikube docker-env)"
    # shellcheck disable=SC2046
    eval $(minikube docker-env)

    log_warn "AVISO: o contexto Docker desta sessão foi alterado para o daemon minikube."
    log_warn "       Imagens buildadas a seguir residem DENTRO do cluster minikube."
    log_warn "       Para restaurar o contexto padrão, execute:"
    log_warn "         eval \$(minikube docker-env --unset)"

    # Confirmar que o daemon apontado é o minikube
    local docker_host
    docker_host="${DOCKER_HOST:-}"
    if [[ -n "${docker_host}" ]]; then
        log_ok "Contexto Docker configurado — DOCKER_HOST: ${docker_host}"
    else
        log_info "DOCKER_HOST não definido (usando socket padrão do minikube via variáveis de ambiente)."
    fi

    log_ok "Etapa 3 concluída — contexto Docker apontando para o daemon minikube."
}

# ---------------------------------------------------------------------------
# ETAPA 4 — Buildar imagens
# ---------------------------------------------------------------------------
step4_build_images() {
    log_step 4 "Buildar imagens Docker no contexto minikube"

    log_info "Executando docker compose build..."
    log_info "Compose file: ${COMPOSE_FILE}"

    if ! docker compose -f "${COMPOSE_FILE}" build; then
        log_error "docker compose build falhou."
        log_error "Verifique os Dockerfiles em apps/api-gateway/ e apps/worker-service/"
        log_summary_fail 4 "docker compose build retornou erro."
        exit 1
    fi

    log_info "Validando presença das imagens no daemon minikube..."

    # Verificar imagem api-gateway
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^api-gateway:"; then
        log_error "Imagem api-gateway não encontrada no daemon minikube após o build."
        log_error "Imagens disponíveis:"
        docker images --format '{{.Repository}}:{{.Tag}}' | head -20 >&2
        log_summary_fail 4 "imagem api-gateway não encontrada após build."
        exit 1
    fi

    # Verificar imagem worker-service
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^worker-service:"; then
        log_error "Imagem worker-service não encontrada no daemon minikube após o build."
        log_error "Imagens disponíveis:"
        docker images --format '{{.Repository}}:{{.Tag}}' | head -20 >&2
        log_summary_fail 4 "imagem worker-service não encontrada após build."
        exit 1
    fi

    log_ok "Etapa 4 concluída — imagens buildadas e validadas no daemon minikube."
    log_info "  api-gateway:    $(docker images api-gateway --format '{{.Repository}}:{{.Tag}}  ({{.Size}})' | head -1)"
    log_info "  worker-service: $(docker images worker-service --format '{{.Repository}}:{{.Tag}}  ({{.Size}})' | head -1)"
}

# ---------------------------------------------------------------------------
# ETAPA 5 — Terraform init
# ---------------------------------------------------------------------------
step5_terraform_init() {
    log_step 5 "Terraform init"

    log_info "Executando: terraform -chdir=${TERRAFORM_DIR} init"

    if ! terraform -chdir="${TERRAFORM_DIR}" init; then
        log_error "terraform init falhou."
        log_error "Verifique a conectividade com registry.terraform.io (necessário para baixar o provider kubernetes)."
        log_error "Diretório terraform: ${TERRAFORM_DIR}"
        log_summary_fail 5 "terraform init retornou erro."
        exit 1
    fi

    log_ok "Etapa 5 concluída — terraform init executado com sucesso."
}

# ---------------------------------------------------------------------------
# ETAPA 6 — Terraform apply
# ---------------------------------------------------------------------------
step6_terraform_apply() {
    log_step 6 "Terraform apply"

    # Garantir contexto kubectl correto antes do apply (evitar apply no Docker Desktop K8s)
    log_info "Definindo contexto kubectl para minikube..."
    if ! kubectl config use-context minikube; then
        log_error "kubectl config use-context minikube falhou."
        log_error "Verifique se o minikube está rodando e o contexto foi criado:"
        log_error "  kubectl config get-contexts"
        log_summary_fail 6 "não foi possível definir contexto kubectl para minikube."
        exit 1
    fi
    log_info "Contexto kubectl: $(kubectl config current-context)"

    log_info "Executando: terraform -chdir=${TERRAFORM_DIR} apply -auto-approve -var=\"image_tag=${IMAGE_TAG}\""

    if ! terraform -chdir="${TERRAFORM_DIR}" apply \
            -auto-approve \
            -var="image_tag=${IMAGE_TAG}"; then
        log_error "terraform apply falhou."
        log_error "Causas comuns:"
        log_error "  - kubeconfig não encontrado: verifique ~/.kube/config"
        log_error "  - contexto incorreto: execute 'kubectl config use-context minikube'"
        log_error "  - nginx ingress addon não está pronto (aguarde a etapa 2 completar)"
        log_error "  - imagens ausentes no daemon minikube (verifique etapa 4)"
        log_summary_fail 6 "terraform apply retornou erro."
        exit 1
    fi

    log_ok "Etapa 6 concluída — terraform apply executado com sucesso."
}

# ---------------------------------------------------------------------------
# ETAPA 7 — Aguardar pods Ready
# ---------------------------------------------------------------------------
step7_wait_pods_ready() {
    log_step 7 "Aguardar pods Ready no namespace ${K8S_NAMESPACE}"

    # api-gateway rollout status
    log_info "Aguardando rollout de api-gateway (timeout: ${POD_READY_TIMEOUT}s)..."
    if ! kubectl rollout status deployment/api-gateway \
            -n "${K8S_NAMESPACE}" \
            --timeout="${POD_READY_TIMEOUT}s"; then
        log_error "Timeout aguardando api-gateway ficar Ready."
        log_error "Diagnóstico:"
        kubectl describe pod -n "${K8S_NAMESPACE}" -l app=api-gateway 2>/dev/null || true
        kubectl logs -n "${K8S_NAMESPACE}" -l app=api-gateway --tail=30 2>/dev/null || true
        log_summary_fail 7 "api-gateway não ficou Ready em ${POD_READY_TIMEOUT}s."
        exit 1
    fi
    log_ok "api-gateway Ready."

    # worker-service rollout status
    log_info "Aguardando rollout de worker-service (timeout: ${POD_READY_TIMEOUT}s)..."
    if ! kubectl rollout status deployment/worker-service \
            -n "${K8S_NAMESPACE}" \
            --timeout="${POD_READY_TIMEOUT}s"; then
        log_error "Timeout aguardando worker-service ficar Ready."
        log_error "Diagnóstico:"
        kubectl describe pod -n "${K8S_NAMESPACE}" -l app=worker-service 2>/dev/null || true
        kubectl logs -n "${K8S_NAMESPACE}" -l app=worker-service --tail=30 2>/dev/null || true
        log_summary_fail 7 "worker-service não ficou Ready em ${POD_READY_TIMEOUT}s."
        exit 1
    fi
    log_ok "worker-service Ready."

    log_ok "Etapa 7 concluída — ambos os pods estão Ready no namespace ${K8S_NAMESPACE}."
    kubectl get pods -n "${K8S_NAMESPACE}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# ETAPA 8 — Validar via curl
# ---------------------------------------------------------------------------
step8_validate_curl() {
    log_step 8 "Validar health check via Ingress nginx"

    local minikube_ip
    minikube_ip="$(minikube ip)"
    local health_url="http://${minikube_ip}/health"

    log_info "minikube IP: ${minikube_ip}"
    log_info "Executando: curl -H \"Host: api-gateway.local\" ${health_url}"

    local http_code
    http_code=$(curl \
        -s \
        -o /dev/null \
        -w "%{http_code}" \
        --max-time "${CURL_TIMEOUT_SECONDS}" \
        -H "Host: api-gateway.local" \
        "${health_url}" \
        2>/dev/null || echo "000")

    if [[ "${http_code}" != "200" ]]; then
        log_error "Esperado HTTP 200, recebido HTTP ${http_code}."
        log_error "Possíveis causas:"
        log_error "  - O Ingress ainda não está pronto (aguarde alguns segundos e tente novamente)"
        log_error "  - O pod api-gateway não está respondendo ao probe /health"
        log_error "  - Verifique: kubectl get ingress -n ${K8S_NAMESPACE}"
        log_error "  - Verifique: kubectl describe ingress -n ${K8S_NAMESPACE}"
        log_summary_fail 8 "curl retornou HTTP ${http_code} em vez de 200."
        exit 1
    fi

    log_ok "Etapa 8 concluída — api-gateway respondeu HTTP 200 via Ingress nginx."
    echo -e "\n${GREEN}${BOLD}  Instrucoes pos-setup:${RESET}"
    echo -e "  ${YELLOW}minikube IP:${RESET} ${minikube_ip}"
    echo -e "  ${YELLOW}Para acessar via hostname, adicione ao /etc/hosts:${RESET}"
    echo -e "    ${BOLD}${minikube_ip}  api-gateway.local${RESET}"
    echo -e "  ${YELLOW}Verificar pods:${RESET}"
    echo -e "    kubectl get pods -n ${K8S_NAMESPACE}"
    echo -e "  ${YELLOW}Teste manual via Ingress:${RESET}"
    echo -e "    curl -H \"Host: api-gateway.local\" http://${minikube_ip}/health"
}

# ---------------------------------------------------------------------------
# Ponto de entrada
# ---------------------------------------------------------------------------
main() {
    echo -e "${BOLD}${CYAN}"
    echo "============================================================"
    echo "  k8s-setup.sh — devops-ai-platform"
    echo "  Setup do ambiente Kubernetes local com minikube + Terraform"
    echo "============================================================"
    echo -e "${RESET}"

    log_info "Repositório raiz: ${REPO_ROOT}"
    log_info "Image tag:        ${IMAGE_TAG}"

    step1_check_prerequisites
    step2_start_minikube
    step3_configure_docker_context
    step4_build_images
    step5_terraform_init
    step6_terraform_apply
    step7_wait_pods_ready
    step8_validate_curl

    log_summary_ok
    exit 0
}

main "$@"
