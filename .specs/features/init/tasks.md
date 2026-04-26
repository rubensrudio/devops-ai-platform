# Tarefas — Init: Estrutura Base da devops-ai-platform

## Resumo

- Total de tarefas: 13
- Tarefas paralelizáveis: 8
- Caminho crítico estimado: TASK-001 → TASK-004 → TASK-005 → TASK-006 → TASK-012

### Distribuição por Risco
- Crítico: 0
- Alto: 3
- Médio: 7
- Baixo: 3

### Distribuição por QA
- full: 3
- wave: 7
- smoke: 2
- auto: 1

### Distribuição por Perfil
- frontend: 0
- backend: 5
- infra: 7
- misto: 1

## Legenda

- `[P]` = Paralelizável com outras `[P]` que não compartilham arquivos
- Esforço: S / M / L
- Tipo: lógica-negócio | crud-padrão | ui-puro | integração-externa | migration | config | refactor | infra | teste
- Risco: crítico | alto | médio | baixo
- QA: full | wave | smoke | auto
- Perfil: frontend | backend | infra | misto

## Tarefas

---

### TASK-001 — Criar estrutura de diretórios base e arquivos de scaffolding

- **Esforço**: S
- **Paralelizável**: Não
- **Depende de**: —
- **Tipo**: config
- **Risco**: médio
- **QA**: wave
- **Perfil**: infra
- **Arquivos**:
  - `.gitignore`
  - `.env.example`
- **Descrição**: Criar os diretórios obrigatórios do repositório (`.claude/memory/`, `.claude/skills/`, `.claude/agents/`, `apps/api-gateway/src/`, `apps/worker-service/src/`, `infra/docker/`, `.github/`, `mcp/`, `scripts/`) com `.gitkeep` onde necessário. Criar `.gitignore` (excluindo `.env`, `node_modules`, `__pycache__`, artefatos de build e arquivos de SO) e `.env.example` com as três variáveis documentadas (`API_PORT=3000`, `HEARTBEAT_INTERVAL=10`, `LOG_LEVEL=info`).
- **Critério de verificação**: Executar `ls -la` recursivo no repositório clonado e confirmar que todos os diretórios obrigatórios existem. Confirmar que `.env` está listado no `.gitignore` e que `.env.example` contém as três variáveis.
- **Status**: ✅ APROVADA em 2026-04-26 — branch: feature/init-TASK-001

---

### TASK-002 [P] — Criar README.md raiz com instruções de setup

- **Esforço**: S
- **Paralelizável**: Sim
- **Depende de**: TASK-001
- **Tipo**: config
- **Risco**: baixo
- **QA**: smoke
- **Perfil**: infra
- **Arquivos**:
  - `README.md`
- **Descrição**: Criar o `README.md` raiz cobrindo: descrição do projeto, pré-requisitos (Docker Desktop com WSL2, Claude Code CLI), passos de setup (`cp .env.example .env` → `docker compose up --build`), comandos principais, localização do `docker-compose.yml` em `infra/docker/`, aviso de que o primeiro build sem cache pode ser lento e que o repositório começa privado. Referenciar os três comandos de skill (`/deploy`, `/rollback`, `/health`) como stubs.
- **Critério de verificação**: Um novo colaborador consegue seguir apenas o `README.md` para subir os serviços — sem precisar de informação externa.
- **Status**: ✅ APROVADA em 2026-04-26 — branch: feature/init-TASK-002

---

### TASK-003 [P] — Criar arquivos de contexto do agente (.claude/CLAUDE.md e memória)

- **Esforço**: S
- **Paralelizável**: Sim
- **Depende de**: TASK-001
- **Tipo**: config
- **Risco**: médio
- **QA**: wave
- **Perfil**: infra
- **Arquivos**:
  - `.claude/CLAUDE.md`
  - `.claude/memory/DECISIONS.md`
- **Descrição**: Criar `.claude/CLAUDE.md` com: objetivo do projeto, lista de skills disponíveis (`/deploy`, `/rollback`, `/health`) com referência aos arquivos, referência aos agents (`deploy-agent`, `review-agent`), convenções de commit e guardrail explícito ("nunca fazer deploy em prod sem aprovação explícita do usuário"). Criar `.claude/memory/DECISIONS.md` com stub inicial contendo o formato de registro `[AAAA-MM-DD] DECISÃO: ... | RACIOCÍNIO: ... | CONTEXTO: ...` e a primeira decisão arquitetural (DA-01 sobre localização do docker-compose.yml).
- **Critério de verificação**: Abrir o repositório no Claude Code e confirmar que o agente cita o objetivo do projeto e as skills disponíveis nas primeiras respostas sem input adicional do usuário. Confirmar que o agente se recusa a executar operações destrutivas se o arquivo for removido ou esvaziado.
- **Status**: ✅ APROVADA em 2026-04-26 — branch: feature/init-TASK-003

---

### TASK-004 [P] — Criar arquivo de lições do agente e stubs de skills/agents

- **Esforço**: S
- **Paralelizável**: Sim
- **Depende de**: TASK-001
- **Tipo**: config
- **Risco**: baixo
- **QA**: auto
- **Perfil**: infra
- **Arquivos**:
  - `.claude/memory/LESSONS.md`
  - `.claude/skills/deploy.md`
- **Descrição**: Criar `.claude/memory/LESSONS.md` com stub inicial e instrução de formato. Criar `.claude/skills/deploy.md` como stub funcional com: descrição da skill, parâmetros esperados (`<env>`), mensagem de stub que o agente deve exibir ("skill em modo stub — não executa ainda"), checklist de verificação de disponibilidade de ferramentas (ex: `kubectl` não disponível no init) e placeholder para implementação futura.
- **Critério de verificação**: Arquivo `.claude/memory/LESSONS.md` existe com formato documentado. Invocar `/deploy staging` no Claude Code e confirmar que o agente lê `skills/deploy.md` e exibe mensagem de stub sem erro.
- **Status**: ✅ APROVADA em 2026-04-26 — branch: feature/init-TASK-004

---

### TASK-005 [P] — Criar stubs das skills rollback e health-check e dos agents

- **Esforço**: S
- **Paralelizável**: Sim
- **Depende de**: TASK-001
- **Tipo**: config
- **Risco**: baixo
- **QA**: smoke
- **Perfil**: infra
- **Arquivos**:
  - `.claude/skills/rollback.md`
  - `.claude/skills/health-check.md`
- **Descrição**: Criar `.claude/skills/rollback.md` como stub com descrição, mensagem de stub e placeholder para lógica real. Criar `.claude/skills/health-check.md` como stub com descrição, status simulado hardcoded (`api-gateway: ok`, `worker-service: ok`) e instrução de que a integração real virá em semana futura. Criar `.claude/agents/deploy-agent.md` e `.claude/agents/review-agent.md` como stubs descrevendo a responsabilidade de cada agent.
- **Critério de verificação**: Invocar `/rollback` e `/health` no Claude Code e confirmar que o agente lê os arquivos correspondentes e responde com mensagem de stub. Confirmar que os dois arquivos de agent existem no diretório correto.
- **Status**: ✅ APROVADA em 2026-04-26 — branch: feature/init-TASK-005

---

### TASK-006 — Implementar api-gateway (Node.js/Express) com endpoint /health

- **Esforço**: M
- **Paralelizável**: Não
- **Depende de**: TASK-001
- **Tipo**: crud-padrão
- **Risco**: alto
- **QA**: full
- **Perfil**: backend
- **Arquivos**:
  - `apps/api-gateway/src/index.js`
  - `apps/api-gateway/package.json`
- **Descrição**: Implementar o serviço `api-gateway` em Node.js com Express. O único endpoint é `GET /health` que retorna HTTP 200 com JSON `{"status": "ok", "service": "api-gateway", "timestamp": "<ISO8601>"}`. Em estado degradado, retorna HTTP 503 com `{"status": "degraded", ...}`. O serviço deve ler `API_PORT` do ambiente (fallback `3000`) e logar na inicialização. Se variáveis de ambiente obrigatórias estiverem ausentes, falhar com mensagem descritiva no stderr.
- **Critério de verificação**: `node src/index.js` sobe o servidor. `curl http://localhost:3000/health` retorna HTTP 200 com JSON no formato especificado. Alterar `API_PORT=4000` e confirmar que sobe na porta correta.

---

### TASK-007 — Implementar worker-service (Python) com loop de heartbeat

- **Esforço**: M
- **Paralelizável**: Não
- **Depende de**: TASK-001
- **Tipo**: lógica-negócio
- **Risco**: alto
- **QA**: full
- **Perfil**: backend
- **Arquivos**:
  - `apps/worker-service/src/main.py`
  - `apps/worker-service/requirements.txt`
- **Descrição**: Implementar o `worker-service` em Python com loop `time.sleep`. A cada `$HEARTBEAT_INTERVAL` segundos (padrão: `10`), escrever no stdout uma linha no formato `[AAAA-MM-DDTHH:MM:SSZ] [worker-service] heartbeat — status: ok`. Se a inicialização falhar por configuração inválida, escrever no stderr e encerrar com exit code não-zero. O loop deve continuar mesmo se recursos externos falharem (modo degradado — não travar o container). Sem dependências externas além da stdlib Python.
- **Critério de verificação**: `python src/main.py` inicia e exibe linhas de heartbeat a cada 10 segundos. `docker logs worker-service` exibe ao menos uma linha de heartbeat sem erros após o container subir.

---

### TASK-008 — Criar Dockerfile do api-gateway com multi-stage build

- **Esforço**: S
- **Paralelizável**: Não
- **Depende de**: TASK-006
- **Tipo**: infra
- **Risco**: médio
- **QA**: wave
- **Perfil**: infra
- **Arquivos**:
  - `apps/api-gateway/Dockerfile`
  - `apps/api-gateway/.dockerignore`
- **Descrição**: Criar Dockerfile com dois estágios: estágio `builder` usando `node:lts` para instalar dependências de produção, e estágio final usando `node:lts-alpine` copiando apenas o necessário (`node_modules` de produção e `src/`). Criar `.dockerignore` excluindo `node_modules`, `*.md`, `.env` e arquivos de desenvolvimento. A imagem final deve expor `$API_PORT` e usar `CMD ["node", "src/index.js"]`.
- **Critério de verificação**: `docker build -t api-gateway .` na pasta `apps/api-gateway/` conclui sem erro. `docker images` mostra que a imagem final (`node:alpine`) é menor que a intermediária (`node:lts`). Container sobe e responde `GET /health` com HTTP 200.

---

### TASK-009 — Criar Dockerfile do worker-service com multi-stage build

- **Esforço**: S
- **Paralelizável**: Não
- **Depende de**: TASK-007
- **Tipo**: infra
- **Risco**: médio
- **QA**: wave
- **Perfil**: infra
- **Arquivos**:
  - `apps/worker-service/Dockerfile`
  - `apps/worker-service/.dockerignore`
- **Descrição**: Criar Dockerfile com dois estágios: estágio `builder` usando `python:3.12` para instalar dependências (se houver), e estágio final usando `python:3.12-slim` copiando apenas `src/` e `requirements.txt`. Criar `.dockerignore` excluindo `__pycache__`, `*.pyc`, `.env` e arquivos de desenvolvimento. A imagem final usa `CMD ["python", "src/main.py"]`.
- **Critério de verificação**: `docker build -t worker-service .` na pasta `apps/worker-service/` conclui sem erro. `docker images` confirma que a imagem final usa `python:slim`. Container sobe e exibe heartbeats no stdout.

---

### TASK-010 — Criar docker-compose.yml orquestrando os dois serviços

- **Esforço**: M
- **Paralelizável**: Não
- **Depende de**: TASK-008, TASK-009
- **Tipo**: infra
- **Risco**: alto
- **QA**: full
- **Perfil**: infra
- **Arquivos**:
  - `infra/docker/docker-compose.yml`
  - `infra/docker/.env.example`
- **Descrição**: Criar `docker-compose.yml` em `infra/docker/` orquestrando `api-gateway` (contexto `../../apps/api-gateway`, porta `${API_PORT:-3000}:${API_PORT:-3000}`) e `worker-service` (contexto `../../apps/worker-service`, sem porta exposta). Ambos os serviços devem carregar variáveis de `.env` via `env_file`, ter `restart: unless-stopped` e estar na mesma rede interna Docker. Criar `.env.example` local (ou referenciar o da raiz) para o Compose. Documentar no `README.md` que o comando é `docker compose -f infra/docker/docker-compose.yml up --build` a partir da raiz.
- **Critério de verificação**: `docker compose -f infra/docker/docker-compose.yml up --build` conclui sem erros. `curl http://localhost:3000/health` retorna HTTP 200. `docker logs worker-service` exibe heartbeats. `docker compose -f infra/docker/docker-compose.yml down` remove todos os containers sem erros. Alterar `API_PORT=4000` no `.env` e confirmar que o gateway sobe na nova porta.

---

### TASK-011 [P] — Criar script de validação da estrutura do repositório

- **Esforço**: S
- **Paralelizável**: Sim
- **Depende de**: TASK-001
- **Tipo**: infra
- **Risco**: médio
- **QA**: wave
- **Perfil**: infra
- **Arquivos**:
  - `scripts/validate-structure.sh`
- **Descrição**: Criar script bash compatível com WSL2/Linux que valida a existência dos diretórios e arquivos obrigatórios (`.claude/`, `apps/api-gateway/`, `apps/worker-service/`, `infra/docker/`, `.github/`, `mcp/`, `scripts/`, `.gitignore`, `.env.example`, `README.md`, `.claude/CLAUDE.md`). Retorna exit code 0 e mensagem de sucesso se tudo estiver presente. Retorna exit code 1 e lista cada item ausente se algum estiver faltando. Adicionar `chmod +x` ao arquivo e documentar no README que requer WSL2 ou ambiente Linux.
- **Critério de verificação**: Executar o script em repositório completo → exit code 0. Remover um diretório obrigatório e executar → exit code 1 listando o item ausente. Restaurar e executar novamente → exit code 0.
- **Status**: ✅ APROVADA em 2026-04-26 — branch: feature/init-TASK-011

---

### TASK-012 — Teste de integração: verificar docker compose up em ambiente limpo

- **Esforço**: S
- **Paralelizável**: Não
- **Depende de**: TASK-010
- **Tipo**: teste
- **Risco**: médio
- **QA**: wave
- **Perfil**: misto
- **Arquivos**:
  - `scripts/smoke-test.sh`
- **Descrição**: Criar script `smoke-test.sh` que executa a sequência completa de validação local: (1) `docker compose up --build -d`, (2) aguarda 15 segundos para os containers estabilizarem, (3) `curl -f http://localhost:$API_PORT/health` e confirma HTTP 200, (4) `docker logs worker-service` e confirma presença de ao menos uma linha de heartbeat no formato correto, (5) `docker compose down` e confirma exit code 0. O script falha com mensagem descritiva em qualquer etapa que não passar.
- **Critério de verificação**: Executar `scripts/smoke-test.sh` em máquina limpa (sem imagens em cache) e confirmar que todas as cinco etapas passam sem intervenção manual. Exit code 0 ao final.

---

### TASK-013 [P] — Configurar .gitattributes e validar .gitignore para ambiente multi-OS

- **Esforço**: S
- **Paralelizável**: Sim
- **Depende de**: TASK-001
- **Tipo**: config
- **Risco**: médio
- **QA**: wave
- **Perfil**: infra
- **Arquivos**:
  - `.gitattributes`
  - `.gitignore`
- **Descrição**: Criar `.gitattributes` configurando `* text=auto eol=lf` para garantir que scripts shell e arquivos de configuração usem LF em todos os ambientes (crítico para scripts bash em WSL2/Windows). Revisar e complementar o `.gitignore` criado na TASK-001 adicionando entradas específicas para Node.js (`dist/`, `*.log`), Python (`*.egg-info/`, `.venv/`), Docker (`*.tar`) e IDEs (`.vscode/`, `.idea/`). Atualizar `.env.example` se necessário para cobrir edge cases de ambiente.
- **Critério de verificação**: `git check-attr text .gitattributes scripts/validate-structure.sh` retorna `text: auto`. Clonar o repositório em ambiente Windows e confirmar que os scripts shell têm terminação LF e são executáveis no WSL2.
- **Status**: ✅ APROVADA em 2026-04-26 — branch: feature/init-TASK-013

---

## Grupos de Paralelização Sugeridos

- **Onda 1** (pode começar imediatamente): TASK-001

- **Onda 2** (após TASK-001 — todas paralelas entre si, não compartilham arquivos):
  - TASK-002 [P] — README.md
  - TASK-003 [P] — .claude/CLAUDE.md + DECISIONS.md
  - TASK-004 [P] — LESSONS.md + skills/deploy.md
  - TASK-005 [P] — skills/rollback.md + health-check.md + agents/
  - TASK-006 — api-gateway src (não paralelizável com TASK-007 por dependência lógica de sequência de review, mas sem conflito de arquivo)
  - TASK-007 — worker-service src (idem)
  - TASK-011 [P] — scripts/validate-structure.sh
  - TASK-013 [P] — .gitattributes + .gitignore complement

- **Onda 3** (após TASK-006 e TASK-007):
  - TASK-008 — Dockerfile api-gateway
  - TASK-009 — Dockerfile worker-service

- **Onda 4** (após TASK-008 e TASK-009):
  - TASK-010 — docker-compose.yml

- **Onda 5** (após TASK-010):
  - TASK-012 — smoke-test.sh + execução de validação final
