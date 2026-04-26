#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh
# Teste de integração local: valida o ciclo completo de docker compose up/down
# para a devops-ai-platform.
#
# Sequência de validação:
#   1. docker compose up --build -d  (a partir da raiz do repositório)
#   2. Aguarda 15 segundos para os containers estabilizarem
#   3. curl -f http://localhost:$API_PORT/health  → confirma HTTP 200
#   4. docker logs worker-service  → confirma ao menos uma linha de heartbeat
#      no formato [AAAA-MM-DDTHH:MM:SSZ] [worker-service] heartbeat — status: ok
#   5. docker compose down  → confirma exit code 0
#
# Uso:
#   ./scripts/smoke-test.sh
#   API_PORT=4000 ./scripts/smoke-test.sh   # porta alternativa
#
# REQUISITOS OBRIGATÓRIOS:
#   - Docker Engine (ou Docker Desktop) com o plugin Compose V2
#   - curl
#   - WSL2 ou ambiente Linux (não compatível com cmd.exe / PowerShell nativos)
#   - bash >= 4.0
#
# NOTA SOBRE DOCKER DESKTOP NO WINDOWS:
#   Este script requer que o Docker Engine esteja disponível no PATH do bash
#   (WSL2 ou Linux). Docker Desktop no Windows expõe o daemon via WSL2
#   integration — certifique-se de que essa integração está habilitada em
#   Docker Desktop → Settings → Resources → WSL Integration.
#
# IMPORTANTE:
#   Este script NÃO foi executado em ambiente com Docker disponível durante
#   a criação (TASK-012). A validação realizada foi estática (bash -n).
#   A execução real requer Docker Engine funcional e deve ser realizada
#   em ambiente com Docker Desktop (WSL2) ou Docker Engine Linux.
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
readonly API_PORT="${API_PORT:-3000}"
readonly HEALTH_URL="http://localhost:${API_PORT}/health"
readonly STARTUP_WAIT_SECONDS=15
readonly CURL_TIMEOUT_SECONDS=10

# Padrão de heartbeat esperado no log do worker-service.
# Formato: [AAAA-MM-DDTHH:MM:SSZ] [worker-service] heartbeat — status: ok
# O em dash (—) é o caractere U+2014; a regex abaixo usa classe ampla para
# compatibilidade com diferentes encodings de terminal.
readonly HEARTBEAT_PATTERN='\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\] \[worker-service\] heartbeat'

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

log_summary_ok() {
    echo -e "\n${GREEN}${BOLD}[${SCRIPT_NAME}] SMOKE TEST PASSOU — todas as 5 etapas concluídas com sucesso.${RESET}"
}

log_summary_fail() {
    local step="$1"
    local reason="$2"
    echo -e "\n${RED}${BOLD}[${SCRIPT_NAME}] SMOKE TEST FALHOU na etapa ${step}: ${reason}${RESET}" >&2
}

# ---------------------------------------------------------------------------
# Verificação de pré-requisitos
# ---------------------------------------------------------------------------
check_prerequisites() {
    log_info "Verificando pré-requisitos..."

    local missing_deps=()

    if ! command -v docker &>/dev/null; then
        missing_deps+=("docker")
    fi

    if ! command -v curl &>/dev/null; then
        missing_deps+=("curl")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependências ausentes: ${missing_deps[*]}"
        log_error "Instale as dependências listadas e execute o script novamente."
        log_error "  docker: https://docs.docker.com/engine/install/"
        log_error "  curl:   sudo apt-get install curl  (Debian/Ubuntu)"
        exit 1
    fi

    # Verificar se o Compose V2 está disponível (docker compose, não docker-compose)
    if ! docker compose version &>/dev/null; then
        log_error "Docker Compose V2 não encontrado (docker compose version falhou)."
        log_error "Verifique se o plugin Compose está instalado:"
        log_error "  https://docs.docker.com/compose/install/"
        exit 1
    fi

    # Verificar se o arquivo docker-compose.yml existe
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        log_error "Arquivo não encontrado: ${COMPOSE_FILE}"
        log_error "Certifique-se de que a TASK-010 foi concluída e o arquivo existe."
        exit 1
    fi

    log_ok "Todos os pré-requisitos satisfeitos."
    log_info "  docker:       $(docker --version)"
    log_info "  curl:         $(curl --version | head -1)"
    log_info "  Compose file: ${COMPOSE_FILE}"
    log_info "  API_PORT:     ${API_PORT}"
    log_info "  Health URL:   ${HEALTH_URL}"
}

# ---------------------------------------------------------------------------
# Cleanup: garantir que os containers são removidos mesmo em caso de falha
# ---------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_info "Executando cleanup (docker compose down) após falha..."
        docker compose -f "${COMPOSE_FILE}" down --remove-orphans 2>/dev/null || true
        log_info "Cleanup concluído."
    fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# ETAPA 1 — docker compose up --build -d
# ---------------------------------------------------------------------------
step1_compose_up() {
    log_step 1 "docker compose up --build -d"
    log_info "Iniciando build e subida dos containers (pode demorar na primeira execução sem cache)..."
    log_info "Compose file: ${COMPOSE_FILE}"
    log_info "Diretório de execução: ${REPO_ROOT}"

    if ! docker compose -f "${COMPOSE_FILE}" up --build -d; then
        log_summary_fail 1 "docker compose up --build -d falhou com exit code não-zero."
        exit 1
    fi

    log_ok "Etapa 1 concluída — containers iniciados em modo detached."
}

# ---------------------------------------------------------------------------
# ETAPA 2 — Aguarda 15 segundos para os containers estabilizarem
# ---------------------------------------------------------------------------
step2_wait() {
    log_step 2 "Aguardando ${STARTUP_WAIT_SECONDS}s para os containers estabilizarem..."

    local i
    for i in $(seq 1 "${STARTUP_WAIT_SECONDS}"); do
        echo -ne "\r  ${YELLOW}Aguardando...${RESET} ${i}/${STARTUP_WAIT_SECONDS}s"
        sleep 1
    done
    echo ""  # nova linha após o contador

    log_ok "Etapa 2 concluída — ${STARTUP_WAIT_SECONDS}s de espera cumpridos."
}

# ---------------------------------------------------------------------------
# ETAPA 3 — curl -f http://localhost:$API_PORT/health → HTTP 200
# ---------------------------------------------------------------------------
step3_health_check() {
    log_step 3 "Verificando health do api-gateway em ${HEALTH_URL}"

    local http_response
    local http_body
    local http_code

    # curl -s = silencioso, -f = falha em 4xx/5xx, -w = write-out com código HTTP
    # --max-time limita o tempo total da requisição
    if ! http_body=$(curl -sf --max-time "${CURL_TIMEOUT_SECONDS}" \
        -w "\n__HTTP_CODE__:%{http_code}" \
        "${HEALTH_URL}" 2>/dev/null); then
        log_error "curl falhou ao conectar em ${HEALTH_URL}."
        log_error "Possíveis causas:"
        log_error "  - O api-gateway ainda não subiu completamente (aumente STARTUP_WAIT_SECONDS)"
        log_error "  - A porta ${API_PORT} está em conflito com outro processo no host"
        log_error "  - O container api-gateway saiu com erro (verifique: docker logs api-gateway)"
        log_summary_fail 3 "curl falhou — api-gateway não respondeu em ${HEALTH_URL}"
        exit 1
    fi

    # Extrair o código HTTP do output formatado
    http_code=$(echo "${http_body}" | grep '__HTTP_CODE__:' | cut -d: -f2)
    http_response=$(echo "${http_body}" | grep -v '__HTTP_CODE__:')

    log_info "Resposta recebida do api-gateway:"
    log_info "  HTTP ${http_code}"
    log_info "  Body: ${http_response}"

    if [[ "${http_code}" != "200" ]]; then
        log_error "Esperado HTTP 200, recebido HTTP ${http_code}."
        log_summary_fail 3 "api-gateway retornou HTTP ${http_code} em vez de 200."
        exit 1
    fi

    log_ok "Etapa 3 concluída — api-gateway respondeu HTTP 200 em ${HEALTH_URL}."
}

# ---------------------------------------------------------------------------
# ETAPA 4 — docker logs worker-service → confirma linha de heartbeat
# ---------------------------------------------------------------------------
step4_worker_heartbeat() {
    log_step 4 "Verificando heartbeat no worker-service..."
    log_info "Padrão esperado: ${HEARTBEAT_PATTERN}"

    local worker_logs
    if ! worker_logs=$(docker logs worker-service 2>&1); then
        log_error "Falha ao obter logs do container worker-service."
        log_error "Verifique se o container existe: docker ps -a | grep worker-service"
        log_summary_fail 4 "docker logs worker-service falhou."
        exit 1
    fi

    if [[ -z "${worker_logs}" ]]; then
        log_error "O container worker-service não produziu nenhuma saída de log."
        log_error "Verifique o status: docker inspect worker-service"
        log_summary_fail 4 "worker-service não produziu logs."
        exit 1
    fi

    # Verificar presença de ao menos uma linha de heartbeat
    local heartbeat_count
    heartbeat_count=$(echo "${worker_logs}" | grep -cE "${HEARTBEAT_PATTERN}" || true)

    if [[ "${heartbeat_count}" -eq 0 ]]; then
        log_error "Nenhuma linha de heartbeat encontrada nos logs do worker-service."
        log_error "Padrão esperado: ${HEARTBEAT_PATTERN}"
        log_error "Primeiras 20 linhas dos logs:"
        echo "${worker_logs}" | head -20 >&2
        log_summary_fail 4 "worker-service não emitiu heartbeat no formato esperado."
        exit 1
    fi

    log_ok "Etapa 4 concluída — ${heartbeat_count} linha(s) de heartbeat encontrada(s) nos logs."
    log_info "Última linha de heartbeat encontrada:"
    echo "${worker_logs}" | grep -E "${HEARTBEAT_PATTERN}" | tail -1 | sed 's/^/  /'
}

# ---------------------------------------------------------------------------
# ETAPA 5 — docker compose down → confirma exit code 0
# ---------------------------------------------------------------------------
step5_compose_down() {
    log_step 5 "docker compose down (teardown dos containers)"

    # Desativa o trap de cleanup para esta etapa (já vamos fazer o down aqui)
    trap - EXIT

    if ! docker compose -f "${COMPOSE_FILE}" down --remove-orphans; then
        log_error "docker compose down falhou com exit code não-zero."
        log_summary_fail 5 "docker compose down retornou erro."
        exit 1
    fi

    log_ok "Etapa 5 concluída — todos os containers removidos com sucesso."
}

# ---------------------------------------------------------------------------
# Ponto de entrada
# ---------------------------------------------------------------------------
main() {
    echo -e "${BOLD}${CYAN}"
    echo "============================================================"
    echo "  smoke-test.sh — devops-ai-platform"
    echo "  Teste de integração: docker compose up/down em ciclo completo"
    echo "============================================================"
    echo -e "${RESET}"

    log_info "Repositório raiz: ${REPO_ROOT}"

    check_prerequisites

    step1_compose_up
    step2_wait
    step3_health_check
    step4_worker_heartbeat
    step5_compose_down

    log_summary_ok
    exit 0
}

main "$@"
