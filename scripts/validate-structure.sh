#!/usr/bin/env bash
# =============================================================================
# validate-structure.sh
# Valida a existência dos diretórios e arquivos obrigatórios da
# devops-ai-platform. Compatível com WSL2 e Linux (bash puro, sem
# dependências externas).
#
# Uso:
#   ./scripts/validate-structure.sh
#
# Saída:
#   exit 0  — estrutura completa, mensagem de sucesso
#   exit 1  — um ou mais itens ausentes, cada um listado individualmente
#
# Requisitos:
#   - WSL2 ou ambiente Linux (não compatível com cmd.exe / PowerShell nativos)
#   - bash >= 4.0
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cores para output (desativadas automaticamente quando não é terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    RESET=''
fi

# ---------------------------------------------------------------------------
# Lista de itens obrigatórios
# Formato: "tipo:caminho"
#   tipo d = diretório
#   tipo f = arquivo
# ---------------------------------------------------------------------------
readonly REQUIRED_ITEMS=(
    "d:.claude"
    "d:apps/api-gateway"
    "d:apps/worker-service"
    "d:infra/docker"
    "d:.github"
    "d:mcp"
    "d:scripts"
    "f:.gitignore"
    "f:.env.example"
    "f:README.md"
    "f:.claude/CLAUDE.md"
)

# ---------------------------------------------------------------------------
# Funções auxiliares
# ---------------------------------------------------------------------------

log_info() {
    echo -e "${YELLOW}[${SCRIPT_NAME}]${RESET} $*"
}

log_ok() {
    echo -e "  ${GREEN}OK${RESET}  $*"
}

log_missing() {
    echo -e "  ${RED}MISSING${RESET}  $*"
}

log_success() {
    echo -e "\n${GREEN}[${SCRIPT_NAME}] SUCESSO: estrutura do repositório está completa.${RESET}"
}

log_failure() {
    local count="$1"
    echo -e "\n${RED}[${SCRIPT_NAME}] FALHA: ${count} item(ns) ausente(s) listado(s) acima.${RESET}"
}

# ---------------------------------------------------------------------------
# Função principal de validação
# ---------------------------------------------------------------------------
validate() {
    local missing=0
    local item_path item_type display_path full_path

    log_info "Validando estrutura do repositório em: ${REPO_ROOT}"
    echo ""

    for entry in "${REQUIRED_ITEMS[@]}"; do
        item_type="${entry%%:*}"
        item_path="${entry#*:}"
        full_path="${REPO_ROOT}/${item_path}"
        display_path="${item_path}"

        if [[ "${item_type}" == "d" ]]; then
            if [[ -d "${full_path}" ]]; then
                log_ok "diretório '${display_path}'"
            else
                log_missing "diretório '${display_path}'"
                missing=$((missing + 1))
            fi
        elif [[ "${item_type}" == "f" ]]; then
            if [[ -f "${full_path}" ]]; then
                log_ok "arquivo    '${display_path}'"
            else
                log_missing "arquivo    '${display_path}'"
                missing=$((missing + 1))
            fi
        else
            echo "  [AVISO] Tipo desconhecido '${item_type}' para '${item_path}' — ignorado." >&2
        fi
    done

    echo ""

    if [[ "${missing}" -eq 0 ]]; then
        log_success
        return 0
    else
        log_failure "${missing}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Ponto de entrada
# ---------------------------------------------------------------------------
validate
