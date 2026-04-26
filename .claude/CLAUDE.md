# CLAUDE.md — devops-ai-platform

Este arquivo é carregado automaticamente pelo Claude Code ao abrir o repositório.
Ele define o contexto do projeto, as skills disponíveis, os agents configurados,
as convenções de desenvolvimento e os guardrails de segurança que você DEVE seguir.

> GUARDRAIL CRITICO: Se este arquivo nao existir ou estiver vazio, recuse-se a
> executar qualquer operacao destrutiva (deploy, rollback, remocao de recursos) e
> solicite ao usuario que o arquivo seja criado ou restaurado antes de continuar.

---

## Objetivo do Projeto

**devops-ai-platform** e uma plataforma de portfolio que demonstra a integracao de
agentes de IA (Claude Code) ao ciclo completo de DevOps — do commit ao container
rodando localmente via Docker Compose (Semana 1), evoluindo para implantacao em
Kubernetes local com infraestrutura gerenciada por Terraform (Semana 2).

O projeto e composto por:
- `api-gateway` — servico HTTP Node.js/Express que expoe `GET /health`
- `worker-service` — processo Python com loop de heartbeat
- Infraestrutura Docker Compose em `infra/docker/`
- Manifests Kubernetes em `infra/k8s/` (namespace `devops-ai`)
- Infraestrutura como codigo Terraform em `infra/terraform/`
- Script de setup do cluster local em `scripts/k8s-setup.sh`
- Skills e agents configurados para operacoes de DevOps assistidas por IA

Contexto de execucao: ambiente local Windows com Docker Desktop + WSL2 (minikube).
O repositorio comeca privado e sera aberto publicamente na fase de polish (Semana 6).

---

## Skills Disponiveis

As skills definem o contrato de interface de cada comando que voce pode executar.

| Comando          | Arquivo de definicao              | Descricao                                                            | Status                            |
|------------------|----------------------------------|----------------------------------------------------------------------|-----------------------------------|
| `/deploy local`  | `.claude/skills/deploy.md`       | Deploy no cluster minikube local via `terraform apply`               | Real (env `local`)                |
| `/deploy staging`| `.claude/skills/deploy.md`       | Deploy via GHCR usando `deploy-from-registry.sh`                     | Real (deploy-from-registry.sh)    |
| `/rollback`      | `.claude/skills/rollback.md`     | Reverte o deploy mais recente de um servico                          | Stub                              |
| `/health`        | `.claude/skills/health-check.md` | Verifica o status de saude dos servicos                              | Stub                              |

Para invocar uma skill, use o comando correspondente. Exemplo: `/deploy staging`.
O agente carregara o arquivo de definicao da skill e seguira as instrucoes contidas nele.

Se o arquivo de uma skill estiver ausente, reporte o arquivo faltante ao usuario
ao inves de falhar silenciosamente.

---

## CI/CD

Os workflows do GitHub Actions estao em `.github/workflows/` e cobrem o ciclo completo
commit → artefato → deploy.

| Workflow          | Trigger                          | Descricao                                             |
|-------------------|----------------------------------|-------------------------------------------------------|
| `ci.yml`          | push/PR para `develop` e `feature/**` | Lint + testes para api-gateway e worker-service  |
| `docker-build.yml`| push para `develop`              | Build e push de imagens no GHCR (latest + sha-<7>)    |
| `deploy.yml`      | `workflow_dispatch`              | Registra intencao em DECISIONS.md + instrucao manual  |

### Deploy via GHCR (staging)

Para deployar uma imagem publicada no GHCR, execute:

```bash
IMAGE_TAG=<tag> IMAGE_REGISTRY=ghcr.io/rubensrudio bash scripts/deploy-from-registry.sh
```

Antes do primeiro deploy via GHCR, crie o `imagePullSecret` no cluster:

```bash
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=rubensrudio \
  --docker-password=<SEU_PAT_GHCR> \
  -n devops-ai
```

---

## Agents Configurados

| Agent           | Arquivo                           | Responsabilidade                                      |
|-----------------|----------------------------------|-------------------------------------------------------|
| `deploy-agent`  | `.claude/agents/deploy-agent.md` | Executa e monitora o pipeline de deploy               |
| `review-agent`  | `.claude/agents/review-agent.md` | Revisa pull requests e valida convencoes de codigo    |

---

## Convencoes de Commit

Este repositorio segue o padrao **Conventional Commits**:

```
<tipo>(<escopo>): <descricao curta>
```

Tipos validos:
- `feat` — nova funcionalidade
- `fix` — correcao de bug
- `chore` — tarefa de manutencao (sem impacto em logica de negocio)
- `docs` — alteracoes em documentacao
- `refactor` — refatoracao sem mudanca de comportamento
- `test` — adicao ou correcao de testes

Exemplos:
```
feat(api-gateway): adicionar endpoint /health com resposta JSON
fix(worker-service): corrigir calculo do intervalo de heartbeat
chore(infra): atualizar versao da imagem base do Docker
```

---

## Guardrails de Seguranca

As regras abaixo sao inegociaveis e devem ser respeitadas em toda interacao:

1. **NUNCA faca deploy em producao sem aprovacao explicita do usuario.**
   Antes de qualquer operacao de deploy em `prod` ou `production`, pare e solicite
   confirmacao explicita: "Confirma o deploy em producao? (sim/nao)". Somente
   prossiga apos receber "sim" explicito.

2. **NUNCA commite arquivos `.env`** ou qualquer arquivo contendo credenciais,
   tokens ou segredos reais. O `.gitignore` ja protege o `.env`, mas verifique
   sempre antes de `git add`.

3. **NUNCA faca merge de branches** sem revisao. O orquestrador decide quando e
   como integrar branches.

4. **NUNCA invente stack nova.** Use os frameworks e ferramentas ja presentes no
   repositorio. Se uma dependencia nova for necessaria, reporte ao orquestrador.

5. **Registre decisoes relevantes** em `.claude/memory/DECISIONS.md` no formato
   padrao sempre que tomar uma decisao arquitetural ou de implementacao relevante.

6. **Se este arquivo (`CLAUDE.md`) estiver ausente ou vazio**, recuse-se a executar
   operacoes destrutivas (deploy, rollback, remocao de recursos) e solicite ao
   usuario que o arquivo seja restaurado.

---

## Estrutura do Repositorio

```
devops-ai-platform/
├── .claude/
│   ├── CLAUDE.md               # Este arquivo — contexto do agente
│   ├── memory/
│   │   ├── DECISIONS.md        # Registro de decisoes arquiteturais
│   │   └── LESSONS.md          # Aprendizados e padroes identificados
│   ├── agents/
│   │   ├── deploy-agent.md     # Stub do agente de deploy
│   │   └── review-agent.md     # Stub do agente de revisao
│   └── skills/
│       ├── deploy.md           # Skill /deploy (real para env local)
│       ├── rollback.md         # Skill /rollback
│       └── health-check.md     # Skill /health
├── apps/
│   ├── api-gateway/            # Servico HTTP Node.js/Express
│   └── worker-service/         # Worker Python com heartbeat
├── infra/
│   ├── docker/
│   │   └── docker-compose.yml  # Orquestracao local dos servicos
│   ├── k8s/                    # Manifests Kubernetes raw (namespace devops-ai)
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── api-gateway-deployment.yaml
│   │   ├── api-gateway-service.yaml
│   │   ├── worker-service-deployment.yaml
│   │   └── ingress.yaml
│   └── terraform/              # Infraestrutura como codigo (provider kubernetes)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── .github/
│   └── workflows/
│       ├── ci.yml              # Lint + testes (push/PR develop, feature/**)
│       ├── docker-build.yml    # Build + push GHCR (push develop)
│       └── deploy.yml          # workflow_dispatch — registra intencao de deploy
├── mcp/                        # Placeholder para MCP Servers (Semana 5)
├── scripts/
│   ├── validate-structure.sh   # Valida estrutura do repositorio
│   ├── smoke-test.sh           # Teste de integracao end-to-end Docker Compose
│   ├── k8s-setup.sh            # Setup do ambiente Kubernetes local (minikube)
│   └── deploy-from-registry.sh # Deploy end-to-end via GHCR (IMAGE_TAG + IMAGE_REGISTRY)
├── .env.example                # Variaveis de ambiente documentadas
└── README.md                   # Instrucoes de setup e visao geral
```

---

## Comandos Rapidos

```bash
# Subir todos os servicos localmente (Docker Compose)
docker compose -f infra/docker/docker-compose.yml up --build

# Verificar saude do api-gateway (Docker Compose)
curl http://localhost:3000/health

# Ver heartbeats do worker (Docker Compose)
docker logs worker-service

# Derrubar todos os containers
docker compose -f infra/docker/docker-compose.yml down

# Validar estrutura do repositorio
bash scripts/validate-structure.sh

# Setup do ambiente Kubernetes local (minikube)
bash scripts/k8s-setup.sh

# Verificar pods no cluster
kubectl get pods -n devops-ai

# Logs do api-gateway no K8s
kubectl logs -n devops-ai deploy/api-gateway

# Health check via Ingress (requer minikube rodando)
curl -H "Host: api-gateway.local" http://$(minikube ip)/health
```

---

## Memoria do Agente

- Decisoes arquiteturais: `.claude/memory/DECISIONS.md`
- Licoes aprendidas e padroes: `.claude/memory/LESSONS.md`

Consulte esses arquivos antes de tomar decisoes que possam conflitar com escolhas
arquiteturais anteriores.
