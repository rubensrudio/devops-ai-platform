# devops-ai-platform

Plataforma de portfólio que integra agentes de IA (Claude Code) ao ciclo completo de
DevOps — do commit ao container rodando localmente, com suporte a deploy, rollback e
health-check orquestrados pelo agente.

O repositório contém dois servicos de aplicacao (`api-gateway` e `worker-service`)
orquestrados via Docker Compose, o contexto do agente Claude Code (`.claude/`) e
stubs de skills e agents para expansao nas semanas seguintes.

> **Repositorio privado**: este repositorio comeca privado no GitHub e sera tornado
> publico apenas na fase de polish (Semana 6). Nao inclua segredos ou credenciais em
> nenhum arquivo versionado.

---

## Indice

1. [Pre-requisitos](#pre-requisitos)
2. [Estrutura do repositorio](#estrutura-do-repositorio)
3. [Setup inicial](#setup-inicial)
4. [Subindo os servicos](#subindo-os-servicos)
5. [Verificando os servicos](#verificando-os-servicos)
6. [Comandos principais](#comandos-principais)
7. [Skills do agente (stubs)](#skills-do-agente-stubs)
8. [Variaveis de ambiente](#variaveis-de-ambiente)
9. [Observacoes importantes](#observacoes-importantes)

---

## Pre-requisitos

Antes de comecar, garanta que as ferramentas abaixo estao instaladas e funcionando
no seu ambiente:

| Ferramenta | Versao minima | Finalidade |
|------------|---------------|------------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | 4.x+ | Rodar containers localmente |
| WSL2 (Windows) | Qualquer | Backend do Docker Desktop no Windows |
| [Claude Code CLI](https://docs.anthropic.com/claude-code) | Latest | Interagir com o agente no repositorio |
| Git | 2.x+ | Clonar e versionar o repositorio |

**Ambiente alvo**: Linux ou Windows com WSL2. Scripts shell (`.sh`) requerem bash
compativel com WSL2 ou ambiente Linux nativo.

**Verificacao rapida:**
```bash
docker --version
docker compose version
claude --version
git --version
```

---

## Estrutura do repositorio

```
devops-ai-platform/
├── .claude/
│   ├── CLAUDE.md               # Contexto do agente — carregado automaticamente
│   ├── memory/
│   │   ├── DECISIONS.md        # Registro de decisoes arquiteturais do agente
│   │   └── LESSONS.md          # Aprendizados identificados pelo agente
│   ├── agents/
│   │   ├── deploy-agent.md     # Stub do agente de deploy
│   │   └── review-agent.md     # Stub do agente de revisao
│   └── skills/
│       ├── deploy.md           # Stub da skill /deploy
│       ├── rollback.md         # Stub da skill /rollback
│       └── health-check.md     # Stub da skill /health
├── apps/
│   ├── api-gateway/            # Servico HTTP (Node.js/Express) — GET /health
│   │   ├── src/
│   │   └── Dockerfile
│   └── worker-service/         # Worker Python com loop de heartbeat
│       ├── src/
│       └── Dockerfile
├── infra/
│   └── docker/
│       └── docker-compose.yml  # Orquestracao local dos dois servicos
├── .github/                    # Placeholder para GitHub Actions (Semana 4)
├── mcp/                        # Placeholder para MCP Servers (Semana 5)
├── scripts/
│   ├── validate-structure.sh   # Valida a estrutura de diretorios do repositorio
│   └── smoke-test.sh           # Teste de integracao end-to-end local
├── .env.example                # Variaveis de ambiente documentadas (sem valores reais)
├── .gitignore
└── README.md                   # Este arquivo
```

---

## Setup inicial

**1. Clone o repositorio** (quando disponivel publicamente ou com acesso):

```bash
git clone <url-do-repositorio>
cd devops-ai-platform
```

**2. Crie o arquivo de variaveis de ambiente locais:**

```bash
cp .env.example .env
```

O arquivo `.env` e ignorado pelo Git (listado no `.gitignore`). Nunca commite o
`.env` — use apenas o `.env.example` para documentar variaveis.

**3. (Opcional) Ajuste as variaveis no `.env`** se precisar mudar portas ou intervalos:

```bash
# Abra com seu editor preferido
nano .env
# ou
code .env
```

---

## Subindo os servicos

O `docker-compose.yml` fica em `infra/docker/`. Execute sempre a partir da
**raiz do repositorio**:

```bash
docker compose -f infra/docker/docker-compose.yml up --build
```

Para rodar em background (modo detached):

```bash
docker compose -f infra/docker/docker-compose.yml up --build -d
```

> **Primeiro build pode ser lento**: na primeira execucao sem cache de imagens Docker,
> o build pode levar varios minutos dependendo da velocidade da conexao e do hardware.
> Builds subsequentes sao significativamente mais rapidos por causa do cache de camadas.

Para parar e remover os containers:

```bash
docker compose -f infra/docker/docker-compose.yml down
```

---

## Verificando os servicos

Apos o `docker compose up`, valide que os servicos subiram corretamente:

**api-gateway — health check:**

```bash
curl http://localhost:3000/health
```

Resposta esperada (HTTP 200):

```json
{
  "status": "ok",
  "service": "api-gateway",
  "timestamp": "2026-04-26T10:00:00.000Z"
}
```

**worker-service — heartbeat nos logs:**

```bash
docker logs worker-service
```

Saida esperada (uma linha a cada 10 segundos por padrao):

```
[2026-04-26T10:00:00Z] [worker-service] heartbeat — status: ok
[2026-04-26T10:00:10Z] [worker-service] heartbeat — status: ok
```

**Validar estrutura do repositorio** (requer WSL2 ou Linux):

```bash
bash scripts/validate-structure.sh
```

---

## Comandos principais

| Comando | Descricao |
|---------|-----------|
| `docker compose -f infra/docker/docker-compose.yml up --build` | Sobe todos os servicos com rebuild |
| `docker compose -f infra/docker/docker-compose.yml up --build -d` | Sobe em background |
| `docker compose -f infra/docker/docker-compose.yml down` | Para e remove os containers |
| `docker compose -f infra/docker/docker-compose.yml logs -f` | Acompanha logs de todos os servicos |
| `docker logs api-gateway` | Logs isolados do api-gateway |
| `docker logs worker-service` | Logs isolados do worker-service |
| `bash scripts/validate-structure.sh` | Valida a estrutura de diretorios |
| `bash scripts/smoke-test.sh` | Executa o teste de integracao end-to-end |

---

## Skills do agente (stubs)

As skills abaixo estao em modo **stub** — definem o contrato de interface do agente
mas nao executam logica real ainda. A implementacao completa sera feita nas semanas
seguintes.

Para usar, abra o repositorio com o Claude Code CLI e invoque os comandos:

**`/deploy <env>`** — Deploy em um ambiente especifico.

```
/deploy staging
/deploy production
```

Arquivo de referencia: `.claude/skills/deploy.md`

**`/rollback`** — Rollback para a versao anterior.

```
/rollback
```

Arquivo de referencia: `.claude/skills/rollback.md`

**`/health`** — Verifica o status dos servicos.

```
/health
```

Arquivo de referencia: `.claude/skills/health-check.md`

> **Nota**: Skills em modo stub exibem mensagem indicando que ainda nao executam
> operacoes reais. O agente reportara o arquivo ausente se alguma skill nao for
> encontrada em `.claude/skills/`.

---

## Variaveis de ambiente

Todas as variaveis sao definidas no `.env.example` e copiadas para `.env` no setup.

| Variavel | Valor padrao | Descricao |
|----------|-------------|-----------|
| `API_PORT` | `3000` | Porta exposta pelo `api-gateway` |
| `HEARTBEAT_INTERVAL` | `10` | Intervalo em segundos do heartbeat do worker |
| `LOG_LEVEL` | `info` | Nivel de log dos servicos (`debug`, `info`, `warn`, `error`) |

**Conflito de porta**: se a porta `3000` ja estiver em uso no seu ambiente, altere
`API_PORT` no `.env` antes de executar o `docker compose up`:

```bash
# .env
API_PORT=4000
```

---

## Observacoes importantes

- **Repositorio privado**: o repositorio comeca privado no GitHub. Nao commite o
  arquivo `.env` nem qualquer segredo. Use sempre o `.env.example` para documentar
  variaveis.

- **Primeiro build lento**: o primeiro `docker compose up --build` sem cache de
  imagens pode levar varios minutos. Isso e comportamento esperado do Docker ao
  baixar imagens base e instalar dependencias.

- **Ambiente Windows**: utilize sempre o WSL2 para executar scripts shell
  (`validate-structure.sh`, `smoke-test.sh`). Scripts com terminacao CRLF podem
  falhar no bash — o `.gitattributes` garante LF para todos os arquivos do
  repositorio.

- **Skills como stubs**: as skills `/deploy`, `/rollback` e `/health` estao em modo
  stub nesta fase. Nao executam operacoes reais (sem deploy efetivo, sem kubectl,
  sem conexao com cluster). A implementacao completa e planejada para as Semanas 3-5.

- **Contexto do agente**: ao abrir o repositorio com o Claude Code, o agente carrega
  automaticamente `.claude/CLAUDE.md`. Se o arquivo estiver ausente ou vazio, o
  agente recusara executar operacoes destrutivas e solicitara que o arquivo seja
  criado.
