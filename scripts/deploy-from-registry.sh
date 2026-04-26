#!/usr/bin/env bash
# =============================================================================
# deploy-from-registry.sh
# Deploy completo da devops-ai-platform a partir de imagens publicadas no GHCR.
#
# Sequência de etapas:
#   1. Validação de pré-requisitos — kubectl, minikube status, terraform validate
#   2. Contexto kubectl — config use-context minikube
#   3. Terraform apply — provisionar infra K8s com image_registry e image_tag
#   4. Rollout wait — aguardar api-gateway e worker-service ficarem Ready
#   5. Health check — GET /health via Ingress nginx retorna 2xx
#   6. Relatório — kubectl get pods + confirmação do deploy concluído
#
# Uso:
#   IMAGE_TAG=sha-abc1234 bash scripts/deploy-from-registry.sh
#   IMAGE_TAG=latest IMAGE_REGISTRY=ghcr.io/rubensrudio bash scripts/deploy-from-registry.sh
#   IMAGE_TAG=sha-abc1234 API_PORT=8080 bash scripts/deploy-from-registry.sh
#
# VARIÁVEIS DE AMBIENTE:
#   IMAGE_TAG         Obrigatório — tag da imagem no GHCR (ex: latest, sha-abc1234)
#   IMAGE_REGISTRY    Opcional   — registry de origem (default: ghcr.io/rubensrudio)
#   API_PORT          Opcional   — porta da api (default: 3000)
#
# REQUISITOS OBRIGATÓRIOS:
#   - kubectl v1.29+    https://kubernetes.io/docs/tasks/tools/
#   - minikube v1.32+   https://minikube.sigs.k8s.io/docs/start/
#   - terraform v1.7+   https://developer.hashicorp.com/terraform/downloads
#   - curl              https://curl.se/
#   - bash >= 4.0
#
# PRÉ-CONDIÇÕES:
#   - minikube deve estar rodando: minikube status
#   - O secret ghcr-credentials deve existir no namespace devops-ai:
#       kubectl create secret docker-registry ghcr-credentials \
#         --docker-server=ghcr.io \
#         --docker-username=<usuario> \
#         --docker-password=<PAT> \
#         -n devops-ai
#   - terraform init já deve ter sido executado em infra/terraform/
#
# IMPORTANTE:
#   Este script foi validado estaticamente (bash -n). A execução real requer
#   o ambiente WSL2 com todas as ferramentas instaladas, minikube rodando e
#   o secret ghcr-credentials criado no cluster.
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
readonly TERRAFORM_DIR="${REPO_ROOT}/infra/terraform"
readonly K8S_NAMESPACE="devops-ai"
readonly IMAGE_REGISTRY="${IMAGE_REGISTRY:-ghcr.io/rubensrudio}"
readonly ROLLOUT_TIMEOUT=120
readonly CURL_TIMEOUT_SECONDS=10

# ---------------------------------------------------------------------------
# Validação obrigatória de IMAGE_TAG
# Deve ser verificada ANTES de qualquer readonly declaration para dar erro claro.
# ---------------------------------------------------------------------------
if [[ -z "${IMAGE_TAG:-}" ]]; then
    # Cores mínimas para o erro antes do bloco de cores estar inicializado
    echo -e "\033[0;31m[${SCRIPT_NAME}] ERRO:\033[0m IMAGE_TAG é obrigatório." >&2
    echo -e "\033[0;31m[${SCRIPT_NAME}] ERRO:\033[0m Defina a variável antes de executar o script:" >&2
    echo -e "\033[0;31m[${SCRIPT_NAME}] ERRO:\033[0m   IMAGE_TAG=sha-abc1234 bash scripts/deploy-from-registry.sh" >&2
    echo -e "\033[0;31m[${SCRIPT_NAME}] ERRO:\033[0m   IMAGE_TAG=latest IMAGE_REGISTRY=ghcr.io/rubensrudio bash scripts/deploy-from-registry.sh" >&2
    exit 1
fi

readonly IMAGE_TAG="${IMAGE_TAG}"

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
    echo -e "\n${GREEN}${BOLD}[${SCRIPT_NAME}] DEPLOY CONCLUIDO — todas as 6 etapas finalizadas com sucesso.${RESET}"
}

log_summary_fail() {
    local step="$1"
    local reason="$2"
    echo -e "\n${RED}${BOLD}[${SCRIPT_NAME}] DEPLOY FALHOU na etapa ${step}: ${reason}${RESET}" >&2
}

# ---------------------------------------------------------------------------
# Cleanup: diagnóstico em caso de falha
# ---------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_warn "Deploy encerrado com falha (exit code ${exit_code}). Executando diagnóstico..."
        log_info "Estado dos pods no namespace ${K8S_NAMESPACE}:"
        kubectl get pods -n "${K8S_NAMESPACE}" 2>/dev/null || true
        log_info "Para diagnóstico detalhado execute:"
        log_info "  kubectl describe pod -n ${K8S_NAMESPACE}"
        log_info "  kubectl logs -n ${K8S_NAMESPACE} -l app=api-gateway --tail=50"
        log_info "  kubectl logs -n ${K8S_NAMESPACE} -l app=worker-service --tail=50"
        log_info "  kubectl get events -n ${K8S_NAMESPACE} --sort-by='.lastTimestamp'"
    fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# ETAPA 1 — Validação de pré-requisitos
# ---------------------------------------------------------------------------
step1_check_prerequisites() {
    log_step 1 "Validação de pré-requisitos"
    log_info "Verificando ferramentas e estado do cluster..."

    # kubectl
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl não encontrado no PATH."
        log_error "  Instale em: https://kubernetes.io/docs/tasks/tools/"
        log_summary_fail 1 "kubectl não encontrado."
        exit 1
    fi

    local kubectl_version
    kubectl_version="$(kubectl version --client 2>/dev/null | head -1 || echo 'versão desconhecida')"
    log_info "  kubectl:    ${kubectl_version}"

    # minikube: verificar se está instalado
    if ! command -v minikube &>/dev/null; then
        log_error "minikube não encontrado no PATH."
        log_error "  Instale em: https://minikube.sigs.k8s.io/docs/start/"
        log_summary_fail 1 "minikube não encontrado."
        exit 1
    fi

    # minikube: verificar se está rodando
    log_info "Verificando status do minikube..."
    local minikube_host_status
    minikube_host_status="$(minikube status --format='{{.Host}}' 2>/dev/null || echo 'Stopped')"

    if [[ "${minikube_host_status}" != "Running" ]]; then
        log_error "minikube não está rodando (status: ${minikube_host_status})."
        log_error "Inicie o minikube antes de executar este script:"
        log_error "  minikube start --driver=docker"
        log_error "Aguarde a inicialização completa antes de tentar o deploy novamente."
        log_summary_fail 1 "minikube não está rodando — execute: minikube start --driver=docker"
        exit 1
    fi

    log_info "  minikube:   Running — $(minikube version --short 2>/dev/null || minikube version | head -1)"

    # terraform
    if ! command -v terraform &>/dev/null; then
        log_error "terraform não encontrado no PATH."
        log_error "  Instale em: https://developer.hashicorp.com/terraform/downloads"
        log_summary_fail 1 "terraform não encontrado."
        exit 1
    fi

    log_info "  terraform:  $(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)"

    # Verificar diretório terraform
    if [[ ! -d "${TERRAFORM_DIR}" ]]; then
        log_error "Diretório terraform não encontrado: ${TERRAFORM_DIR}"
        log_error "Certifique-se de que a task T-04 foi concluída."
        log_summary_fail 1 "diretório infra/terraform não encontrado."
        exit 1
    fi

    # terraform validate
    log_info "Executando terraform validate em ${TERRAFORM_DIR}..."
    if ! terraform -chdir="${TERRAFORM_DIR}" validate; then
        log_error "terraform validate falhou — configuração inválida em ${TERRAFORM_DIR}."
        log_error "Corrija os erros de sintaxe/configuração antes de prosseguir."
        log_summary_fail 1 "terraform validate retornou erro."
        exit 1
    fi

    log_ok "Todos os pré-requisitos validados."
    log_info "  IMAGE_REGISTRY:  ${IMAGE_REGISTRY}"
    log_info "  IMAGE_TAG:       ${IMAGE_TAG}"
    log_info "  API_PORT:        ${API_PORT:-3000}"
    log_info "  Terraform dir:   ${TERRAFORM_DIR}"
    log_info "  Namespace K8s:   ${K8S_NAMESPACE}"
}

# ---------------------------------------------------------------------------
# ETAPA 2 — Contexto kubectl
# ---------------------------------------------------------------------------
step2_set_kubectl_context() {
    log_step 2 "Definir contexto kubectl para minikube"

    log_info "Executando: kubectl config use-context minikube"

    if ! kubectl config use-context minikube; then
        log_error "kubectl config use-context minikube falhou."
        log_error "Verifique os contextos disponíveis:"
        log_error "  kubectl config get-contexts"
        log_summary_fail 2 "não foi possível definir contexto kubectl para minikube."
        exit 1
    fi

    local current_context
    current_context="$(kubectl config current-context)"
    log_ok "Contexto kubectl definido: ${current_context}"
}

# ---------------------------------------------------------------------------
# ETAPA 3 — Terraform apply
# ---------------------------------------------------------------------------
step3_terraform_apply() {
    log_step 3 "Terraform apply — provisionar infraestrutura K8s com imagem do registry"

    log_info "Executando terraform apply com:"
    log_info "  image_registry = ${IMAGE_REGISTRY}"
    log_info "  image_tag      = ${IMAGE_TAG}"
    log_info "  api_port       = ${API_PORT:-3000}"

    if ! terraform -chdir="${TERRAFORM_DIR}" apply \
            -auto-approve \
            -var="image_registry=${IMAGE_REGISTRY}" \
            -var="image_tag=${IMAGE_TAG}" \
            -var="api_port=${API_PORT:-3000}"; then
        log_error "terraform apply falhou."
        log_error "Causas comuns:"
        log_error "  - kubeconfig não encontrado ou contexto incorreto (verifique ~/.kube/config)"
        log_error "  - secret ghcr-credentials ausente no namespace ${K8S_NAMESPACE}"
        log_error "    Crie o secret com:"
        log_error "      kubectl create secret docker-registry ghcr-credentials \\"
        log_error "        --docker-server=ghcr.io \\"
        log_error "        --docker-username=<usuario> \\"
        log_error "        --docker-password=<PAT> \\"
        log_error "        -n ${K8S_NAMESPACE}"
        log_error "  - tag ${IMAGE_TAG} inexistente em ${IMAGE_REGISTRY}"
        log_error "  - terraform init não foi executado — rode: terraform -chdir=${TERRAFORM_DIR} init"
        log_summary_fail 3 "terraform apply retornou erro."
        exit 1
    fi

    log_ok "Etapa 3 concluída — terraform apply executado com sucesso."
}

# ---------------------------------------------------------------------------
# ETAPA 4 — Rollout wait
# ---------------------------------------------------------------------------
step4_rollout_wait() {
    log_step 4 "Aguardar rollout dos deployments no namespace ${K8S_NAMESPACE}"

    # api-gateway rollout status
    log_info "Aguardando rollout de api-gateway (timeout: ${ROLLOUT_TIMEOUT}s)..."
    if ! kubectl rollout status deployment/api-gateway \
            -n "${K8S_NAMESPACE}" \
            --timeout="${ROLLOUT_TIMEOUT}s"; then
        log_error "Timeout aguardando api-gateway ficar Ready em ${ROLLOUT_TIMEOUT}s."
        log_error "Diagnóstico:"
        kubectl describe pod -n "${K8S_NAMESPACE}" -l app=api-gateway 2>/dev/null || true
        kubectl logs -n "${K8S_NAMESPACE}" -l app=api-gateway --tail=30 2>/dev/null || true
        log_error "Causas comuns:"
        log_error "  - ImagePullBackOff: secret ghcr-credentials ausente ou inválido"
        log_error "  - ErrImageNeverPull: image_registry vazio com imagePullPolicy=Never"
        log_error "  - tag ${IMAGE_TAG} inexistente no registry ${IMAGE_REGISTRY}"
        log_summary_fail 4 "api-gateway não ficou Ready em ${ROLLOUT_TIMEOUT}s."
        exit 1
    fi

    log_ok "api-gateway Ready."

    # worker-service rollout status
    log_info "Aguardando rollout de worker-service (timeout: ${ROLLOUT_TIMEOUT}s)..."
    if ! kubectl rollout status deployment/worker-service \
            -n "${K8S_NAMESPACE}" \
            --timeout="${ROLLOUT_TIMEOUT}s"; then
        log_error "Timeout aguardando worker-service ficar Ready em ${ROLLOUT_TIMEOUT}s."
        log_error "Diagnóstico:"
        kubectl describe pod -n "${K8S_NAMESPACE}" -l app=worker-service 2>/dev/null || true
        kubectl logs -n "${K8S_NAMESPACE}" -l app=worker-service --tail=30 2>/dev/null || true
        log_error "Causas comuns:"
        log_error "  - ImagePullBackOff: secret ghcr-credentials ausente ou inválido"
        log_error "  - ErrImageNeverPull: image_registry vazio com imagePullPolicy=Never"
        log_error "  - tag ${IMAGE_TAG} inexistente no registry ${IMAGE_REGISTRY}"
        log_summary_fail 4 "worker-service não ficou Ready em ${ROLLOUT_TIMEOUT}s."
        exit 1
    fi

    log_ok "worker-service Ready."
    log_ok "Etapa 4 concluída — ambos os deployments estão Ready no namespace ${K8S_NAMESPACE}."
}

# ---------------------------------------------------------------------------
# ETAPA 5 — Health check
# ---------------------------------------------------------------------------
step5_health_check() {
    log_step 5 "Health check via Ingress nginx"

    local minikube_ip
    minikube_ip="$(minikube ip)"
    local health_url="http://${minikube_ip}/health"

    log_info "minikube IP: ${minikube_ip}"
    log_info "Executando: curl -sf -H \"Host: api-gateway.local\" ${health_url}"

    local http_code
    local curl_exit=0
    http_code=$(curl \
        -s \
        -o /dev/null \
        -w "%{http_code}" \
        --max-time "${CURL_TIMEOUT_SECONDS}" \
        -H "Host: api-gateway.local" \
        "${health_url}" \
        2>/dev/null) || curl_exit=$?

    if [[ ${curl_exit} -ne 0 ]]; then
        log_error "curl falhou com código de saída ${curl_exit} ao acessar ${health_url}."
        log_error "Possíveis causas:"
        log_error "  - O Ingress nginx ainda não está pronto (aguarde alguns segundos)"
        log_error "  - minikube IP inacessível da sessão WSL2 atual"
        log_error "  - Verifique: kubectl get ingress -n ${K8S_NAMESPACE}"
        log_error "Logs do api-gateway:"
        kubectl logs -n "${K8S_NAMESPACE}" -l app=api-gateway --tail=20 2>/dev/null || true
        log_summary_fail 5 "curl falhou com exit code ${curl_exit} — health check não respondeu."
        exit 1
    fi

    # Validar que o código HTTP é 2xx
    local http_class="${http_code:0:1}"
    if [[ "${http_class}" != "2" ]]; then
        log_error "Esperado HTTP 2xx, recebido HTTP ${http_code}."
        log_error "Possíveis causas:"
        log_error "  - O api-gateway não está respondendo ao probe /health"
        log_error "  - O Ingress ainda não redirecionou o tráfego corretamente"
        log_error "  - Verifique: kubectl describe ingress -n ${K8S_NAMESPACE}"
        log_error "Logs do api-gateway:"
        kubectl logs -n "${K8S_NAMESPACE}" -l app=api-gateway --tail=20 2>/dev/null || true
        log_summary_fail 5 "api-gateway retornou HTTP ${http_code} em vez de 2xx."
        exit 1
    fi

    log_ok "Etapa 5 concluída — api-gateway respondeu HTTP ${http_code} via Ingress nginx."
}

# ---------------------------------------------------------------------------
# ETAPA 6 — Relatório
# ---------------------------------------------------------------------------
step6_report() {
    log_step 6 "Relatório do deploy"

    log_info "Estado dos pods no namespace ${K8S_NAMESPACE}:"
    kubectl get pods -n "${K8S_NAMESPACE}" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}${BOLD}  Deploy concluído: ${IMAGE_REGISTRY}/api-gateway:${IMAGE_TAG}${RESET}"
    echo -e "${GREEN}${BOLD}  Deploy concluído: ${IMAGE_REGISTRY}/worker-service:${IMAGE_TAG}${RESET}"
    echo ""
    log_info "  IMAGE_REGISTRY:  ${IMAGE_REGISTRY}"
    log_info "  IMAGE_TAG:       ${IMAGE_TAG}"
    log_info "  Namespace K8s:   ${K8S_NAMESPACE}"
    log_info "  minikube IP:     $(minikube ip 2>/dev/null || echo 'indisponível')"
    echo -e "  ${YELLOW}Para acessar via hostname, certifique-se de ter no /etc/hosts:${RESET}"
    echo -e "    ${BOLD}$(minikube ip 2>/dev/null || echo '<minikube-ip>')  api-gateway.local${RESET}"
    echo -e "  ${YELLOW}Teste manual via Ingress:${RESET}"
    echo -e "    curl -H \"Host: api-gateway.local\" http://$(minikube ip 2>/dev/null || echo '<minikube-ip>')/health"
}

# ---------------------------------------------------------------------------
# Ponto de entrada
# ---------------------------------------------------------------------------
main() {
    echo -e "${BOLD}${CYAN}"
    echo "============================================================"
    echo "  deploy-from-registry.sh — devops-ai-platform"
    echo "  Deploy a partir do GitHub Container Registry (GHCR)"
    echo "============================================================"
    echo -e "${RESET}"

    log_info "Repositório raiz:  ${REPO_ROOT}"
    log_info "IMAGE_REGISTRY:    ${IMAGE_REGISTRY}"
    log_info "IMAGE_TAG:         ${IMAGE_TAG}"

    step1_check_prerequisites
    step2_set_kubectl_context
    step3_terraform_apply
    step4_rollout_wait
    step5_health_check
    step6_report

    log_summary_ok
    exit 0
}

main "$@"
