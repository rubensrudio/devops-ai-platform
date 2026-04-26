# Plano Técnico — Init: Estrutura Base da devops-ai-platform

## 1. Resumo Executivo

A feature `init` estabelece a fundação completa do repositório `devops-ai-platform` — um projeto de portfólio que demonstra a integração de agentes de IA (Claude Code) ao ciclo completo de DevOps. O trabalho abrange quatro frentes: a estrutura de diretórios canônica do repositório, dois serviços de aplicação funcionais (`api-gateway` e `worker-service`) orquestrados via Docker Compose, o contexto de agente (`CLAUDE.md` + arquivos de memória) e os stubs de skills/agents que serão expandidos nas semanas seguintes.

Por ser um projeto greenfield, não há código existente a ser adaptado. Toda decisão arquitetural parte do zero, o que elimina riscos de acoplamento com sistemas legados mas exige atenção especial às lacunas de especificação — principalmente a escolha de linguagem/framework dos serviços, que ainda não foi definida no spec.

O impacto desta feature é de desbloqueio: nenhuma outra feature da plataforma pode ser desenvolvida antes da conclusão do `init`. O critério de aceite final é simples e verificável: `git clone` + `docker compose up --build` funcionando em máquina limpa, com os dois serviços acessíveis e o agente carregando contexto do `CLAUDE.md` sem input adicional do usuário.

A estimativa de esforço é de 1 semana de trabalho para as stories P1 (MVP). As stories P2 (multi-stage Dockerfile) e P3 (script de validação) são incrementais e podem ser entregues em sequência ou paralelamente, sem bloquear o MVP.

---

## 2. Premissas e Lacunas do Spec

As lacunas abaixo foram marcadas explicitamente no spec com `[LACUNA: ...]`. Nenhuma delas foi inventada ou resolvida aqui — devem ser resolvidas pelo autor do spec antes da implementação das tasks que as consomem.

| ID | Tipo | Lacuna | Impacto nas Tasks |
|----|------|--------|-------------------|
| LACUNA-1 | Tecnologia | A linguagem/framework do `api-gateway` não está definida — o spec menciona "Node.js/FastAPI" (tecnologias incompatíveis entre si). Qual é a escolha final? | Bloqueia a criação do `Dockerfile.api` e de qualquer código do serviço |
| LACUNA-2 | Tecnologia | A linguagem/framework do `worker-service` e o sistema de fila que ele consome (RabbitMQ, SQS, Redis Streams ou nenhum nesta fase) não estão definidos | Bloqueia a criação do `Dockerfile.worker` e a lógica de heartbeat |
| LACUNA-3 | Ambiente | O ambiente de desenvolvimento alvo não está definido (Mac, Linux ou Windows com WSL) — impacta caminhos no `docker-compose.yml`, scripts shell e `.gitattributes` | Impacta configuração do Compose e scripts de setup |
| LACUNA-4 | Portfólio | O repositório será público no GitHub desde o início ou somente após o polish? | Impacta o `.gitignore`, gestão de secrets e o que vai para o `README.md` |

**Premissas adotadas neste plano** (válidas apenas até que as lacunas sejam respondidas):

- P1: Dado que o projeto é de portfólio e menciona Node.js e Python, assume-se que o `api-gateway` usará **Node.js com Express** (minimal, sem framework pesado) e o `worker-service` usará **Python** (por afinidade com tooling de IA). Se a decisão for diferente, as tasks de Dockerfile e código precisarão ser revisadas.
- P2: O `worker-service` não consumirá fila real nesta fase — o heartbeat será implementado como loop `setInterval`/`time.sleep` simples. A conexão com fila é out of scope para o `init`.
- P3: O ambiente alvo primário é **Linux/WSL** para compatibilidade com Docker Desktop e CI futura.
- P4: O repositório começará **privado** no GitHub, tornando-se público na semana de polish. Nenhum segredo será hardcoded.

---

## 3. Arquitetura Proposta

### 3.1 Visão de Componentes

```
devops-ai-platform/
├── .claude/
│   ├── CLAUDE.md               # Contexto do agente — carregado automaticamente pelo Claude Code
│   ├── memory/
│   │   ├── DECISIONS.md        # Registro de decisões arquiteturais do agente
│   │   └── LESSONS.md          # Aprendizados e padrões identificados pelo agente
│   ├── agents/
│   │   ├── deploy-agent.md     # Stub do agente de deploy
│   │   └── review-agent.md     # Stub do agente de revisão
│   └── skills/
│       ├── deploy.md           # Stub da skill /deploy
│       ├── rollback.md         # Stub da skill /rollback
│       └── health-check.md     # Stub da skill /health
├── apps/
│   ├── api-gateway/
│   │   ├── src/                # Código fonte do serviço
│   │   └── Dockerfile          # Multi-stage build (P2)
│   └── worker-service/
│       ├── src/                # Código fonte do worker
│       └── Dockerfile          # Multi-stage build (P2)
├── infra/
│   └── docker/
│       └── docker-compose.yml  # Orquestração local de todos os serviços
├── .github/
│   └── .gitkeep                # Placeholder para workflows futuros (Semana 4)
├── mcp/
│   └── .gitkeep                # Placeholder para MCP Servers (Semana 5)
├── scripts/
│   └── validate-structure.sh   # Script de validação da estrutura (P3)
├── .gitignore
├── .env.example                # Variáveis de ambiente documentadas (sem valores reais)
└── README.md                   # Instruções de setup e visão geral do projeto
```

**Componentes principais:**

| Componente | Responsabilidade | Porta |
|------------|-----------------|-------|
| `api-gateway` | Serviço HTTP que expõe `GET /health` com resposta 200 | `${API_PORT:-3000}` |
| `worker-service` | Processo de background que emite heartbeat a cada intervalo configurado | N/A (sem porta exposta) |
| `docker-compose.yml` | Orquestra os dois serviços em rede interna Docker, carrega variáveis de `.env` | — |
| `CLAUDE.md` | Instrui o agente sobre objetivo do projeto, skills disponíveis, convenções de commit e guardrails de segurança | — |
| Skills (stubs) | Arquivos Markdown que definem o contrato de interface de cada comando do agente | — |

### 3.2 Fluxo Principal

**Fluxo de setup (desenvolvedor):**

```
git clone → cp .env.example .env → docker compose up --build
                                          |
                              [api-gateway sobe na porta $API_PORT]
                              [worker-service inicia loop de heartbeat]
                                          |
                              curl http://localhost:$API_PORT/health → 200 OK
                              docker logs worker-service → heartbeat a cada $HEARTBEAT_INTERVAL
```

**Fluxo do agente (Claude Code):**

```
Abertura do repositório no Claude Code
        |
Claude Code carrega automaticamente .claude/CLAUDE.md
        |
Agente cita contexto do projeto sem input adicional do usuário
        |
Usuário invoca /deploy <env> → agente carrega .claude/skills/deploy.md → exibe mensagem de stub
Usuário invoca /rollback    → agente carrega .claude/skills/rollback.md → exibe mensagem de stub
Usuário invoca /health      → agente carrega .claude/skills/health-check.md → exibe status simulado
        |
Agente registra decisões relevantes em .claude/memory/DECISIONS.md
```

### 3.3 Decisões Arquiteturais

**DA-01: Localização do `docker-compose.yml`**

- Opção escolhida: `infra/docker/docker-compose.yml` com symlink ou referência explícita na raiz
- Alternativa descartada: `docker-compose.yml` direto na raiz
- Raciocínio: A proposta define a pasta `infra/` como container de artefatos de infraestrutura. Manter o Compose ali é coerente com a estrutura futura (Terraform, k8s manifests virão na Semana 3). O `README.md` documenta o caminho completo.
- Trade-off: O comando `docker compose up` precisará ser executado com `-f infra/docker/docker-compose.yml` a partir da raiz, ou o `README.md` deve orientar o usuário a entrar no diretório. Alternativa: arquivo `docker-compose.yml` na raiz que usa `extends` ou referencia o arquivo em `infra/`.

**DA-02: Arquivos de skill como Markdown**

- Opção escolhida: Skills em `.claude/skills/` como arquivos `.md` simples (stubs descritivos)
- Raciocínio: Claude Code carrega arquivos Markdown como contexto nativo. Stubs em Markdown definem o contrato de interface sem exigir execução. A lógica real será implementada nas semanas seguintes.
- Trade-off: Não é possível executar um `.md` diretamente — o agente interpreta e age. Isso é intencional para o `init`.

**DA-03: Variáveis de ambiente via `.env`**

- Opção escolhida: `.env.example` no repositório com todos os valores padrão documentados; `.env` local nunca commitado
- Raciocínio: Porta do `api-gateway` configurável via variável de ambiente (`API_PORT`) — requisito explícito do edge case de conflito de porta. O `.gitignore` deve incluir `.env`.
- Trade-off: Requer um passo manual de `cp .env.example .env` no setup inicial, documentado no `README.md`.

**DA-04: Multi-stage Dockerfiles (P2)**

- Opção escolhida: Dockerfiles com estágio `builder` e estágio final usando imagem base mínima
- Raciocínio: Reduz tamanho da imagem de produção e evita incluir dependências de desenvolvimento. Boa prática de portfólio.
- Trade-off: Complexidade levemente maior no Dockerfile; justificada pelo valor demonstrável no portfólio.

---

## 4. Modelos de Dados

Esta feature não introduz banco de dados, migrations ou modelos de domínio persistidos. Os únicos "modelos de dados" desta fase são:

**Variáveis de ambiente (`.env.example`):**

| Variável | Tipo | Valor padrão | Descrição |
|----------|------|-------------|-----------|
| `API_PORT` | integer | `3000` | Porta exposta pelo `api-gateway` |
| `HEARTBEAT_INTERVAL` | integer | `10` | Intervalo em segundos do heartbeat do worker |
| `LOG_LEVEL` | string | `info` | Nível de log dos serviços |

**Formato do registro de decisão do agente (`.claude/memory/DECISIONS.md`):**

```
[AAAA-MM-DD] DECISÃO: <decisão tomada> | RACIOCÍNIO: <justificativa> | CONTEXTO: <situação que motivou>
```

**Formato do heartbeat do `worker-service` (stdout):**

```
[AAAA-MM-DDTHH:MM:SSZ] [worker-service] heartbeat — status: ok
```

---

## 5. Contratos de API

### `api-gateway`

**`GET /health`**

- Propósito: Verificação de saúde do serviço
- Autenticação: Nenhuma (endpoint público, sem auth — ver Seção 8)
- Request: Sem body, sem query params
- Response de sucesso:

```json
HTTP 200 OK
Content-Type: application/json

{
  "status": "ok",
  "service": "api-gateway",
  "timestamp": "2026-04-26T10:00:00.000Z"
}
```

- Response de erro (serviço em estado degradado):

```json
HTTP 503 Service Unavailable
Content-Type: application/json

{
  "status": "degraded",
  "service": "api-gateway",
  "timestamp": "2026-04-26T10:00:00.000Z"
}
```

**Nota:** Nenhum outro endpoint está no escopo do `init`. O `api-gateway` serve exclusivamente como demonstração de saúde do serviço.

### `worker-service`

Não expõe HTTP. Contrato de comportamento observável:

- A cada `$HEARTBEAT_INTERVAL` segundos, escreve no stdout uma linha no formato definido na Seção 4
- Se não conseguir inicializar (ex: configuração inválida), escreve no stderr e encerra com exit code não-zero
- Não trava o container em modo degradado — continua o loop mesmo se recursos externos falharem (edge case explícito no spec)

---

## 6. Componentes Afetados

Por ser greenfield, não há componentes existentes. A tabela abaixo lista os arquivos e diretórios que serão **criados** e o impacto de cada um:

| Arquivo / Diretório | Ação | Impacto |
|--------------------|----|---------|
| `README.md` | Criar | Ponto de entrada do repositório; deve cobrir setup, estrutura, comandos e comportamento esperado no primeiro build |
| `.gitignore` | Criar | Exclui `.env`, `node_modules`, `__pycache__`, artefatos de build e arquivos de SO |
| `.env.example` | Criar | Documenta todas as variáveis de ambiente obrigatórias com valores padrão seguros |
| `docker-compose.yml` (raiz ou `infra/docker/`) | Criar | Orquestra os dois serviços; define redes, volumes, variáveis de ambiente e políticas de restart |
| `apps/api-gateway/` | Criar | Código fonte e Dockerfile do gateway; ponto de verificação mais visível da plataforma |
| `apps/worker-service/` | Criar | Código fonte e Dockerfile do worker; demonstra processo de background |
| `.claude/CLAUDE.md` | Criar | Contexto carregado automaticamente pelo Claude Code; guardrails de segurança do agente |
| `.claude/memory/DECISIONS.md` | Criar | Stub inicial com instrução de formato; será populado pelo agente durante uso |
| `.claude/memory/LESSONS.md` | Criar | Stub inicial com instrução de formato; será populado pelo agente durante uso |
| `.claude/skills/deploy.md` | Criar | Stub da skill `/deploy`; define contrato de interface para implementação futura |
| `.claude/skills/rollback.md` | Criar | Stub da skill `/rollback`; idem |
| `.claude/skills/health-check.md` | Criar | Stub da skill `/health`; idem |
| `.claude/agents/deploy-agent.md` | Criar | Stub do deploy agent |
| `.claude/agents/review-agent.md` | Criar | Stub do review agent |
| `.github/.gitkeep` | Criar | Placeholder para workflows da Semana 4 |
| `mcp/.gitkeep` | Criar | Placeholder para MCP Servers da Semana 5 |
| `scripts/validate-structure.sh` | Criar (P3) | Script de validação da estrutura do repositório |

---

## 7. Dependências Externas

| Dependência | Tipo | Necessidade | Status |
|-------------|------|-------------|--------|
| Docker Desktop (ou Docker Engine + Compose plugin) | Infra local | Obrigatório para subir os serviços | Deve ser instalado pelo desenvolvedor — não gerenciado pelo repositório |
| Node.js (se `api-gateway` for Node) | Runtime | Necessário apenas fora do Docker (desenvolvimento local) | Resolvido internamente no Dockerfile |
| Python (se `worker-service` for Python) | Runtime | Necessário apenas fora do Docker (desenvolvimento local) | Resolvido internamente no Dockerfile |
| Claude Code CLI | Ferramenta | Obrigatório para interação com o agente | Instalado pelo desenvolvedor |
| GitHub (repositório remoto) | Plataforma | Necessário para clone e futuras features | Criação do repositório remoto é pré-requisito de deploy; não está no escopo do `init` |

**Sem dependências de serviços terceiros pagos, APIs externas ou credenciais sensíveis nesta fase.**

---

## 8. Áreas Sensíveis

- **Autenticação/autorização/sessão**: NÃO. O spec explicitamente exclui autenticação/segurança do escopo desta fase. O único endpoint público é `GET /health`, que é intencional e sem dados sensíveis.

- **Pagamento/faturamento/cálculo financeiro real**: NÃO. Fora do escopo da plataforma de portfólio.

- **Dados pessoais/sensíveis (PII, saúde, financeiro)**: NÃO. Nenhum dado de usuário é coletado ou processado nesta fase.

- **Migration de dados em tabela com produção**: NÃO. Projeto greenfield, sem banco de dados, sem produção ainda.

- **Lógica regulatória/fiscal/compliance**: NÃO.

- **Endpoint público sem autenticação prévia**: SIM. `GET /health` no `api-gateway` é um endpoint HTTP público sem qualquer autenticação. Componentes envolvidos: `apps/api-gateway/` e `infra/docker/docker-compose.yml`. Risco classificado como BAIXO para esta fase (dado que é ambiente local/desenvolvimento e o dado retornado é apenas status do serviço, sem informações sensíveis). Para ambientes futuros expostos, deverá ser protegido por rede ou auth.

- **Criptografia/manuseio de chaves**: NÃO. Nenhuma chave é utilizada nesta fase. O `.gitignore` protege o `.env` de ser commitado.

- **Integração externa nova com terceiro**: NÃO. Nenhuma API ou serviço externo é integrado no `init`.

---

## 9. Riscos e Mitigações

| # | Risco | Impacto | Probabilidade | Mitigação |
|---|-------|---------|---------------|-----------|
| R1 | LACUNA-1 e LACUNA-2 não respondidas antes do início da implementação | Alto — bloqueia a criação dos Dockerfiles e do código dos serviços | Alta — as lacunas existem e não foram resolvidas no spec | Resolver as lacunas antes de criar tasks para os serviços; as tasks de estrutura de diretórios, CLAUDE.md e skills podem começar em paralelo |
| R2 | Conflito de opinião sobre onde colocar o `docker-compose.yml` (raiz vs `infra/docker/`) | Médio — retrabalho de referências no README e nos scripts | Baixa | Decisão DA-01 define a posição; registrar como decisão antes de implementar e não revisitar |
| R3 | Ambiente Windows sem WSL2 configurado corretamente | Alto — Docker Desktop com WSL2 é o ambiente de desenvolvimento do Rubens; caminhos de volume podem se comportar diferente | Média | Documentar no README os requisitos mínimos de ambiente; testar o `docker compose up` no ambiente real antes de marcar a feature como concluída |
| R4 | Claude Code não carrega `.claude/CLAUDE.md` automaticamente se o arquivo estiver no subdiretório errado | Alto — compromete o critério de aceite mais importante da feature | Baixa | Verificar na documentação do Claude Code o caminho exato esperado para o CLAUDE.md; o caminho canônico é `.claude/CLAUDE.md` na raiz do repositório |
| R5 | Imagem Docker com multi-stage build (P2) resulta em tempo de build lento no primeiro `docker compose up --build` | Baixo — não impede o funcionamento; apenas experiência degradada | Alta — primeiro build sem cache é sempre lento | Documentar no README que o primeiro build pode levar alguns minutos; usar `.dockerignore` para excluir artefatos desnecessários do contexto de build |
| R6 | Script de validação de estrutura (P3) escrito em bash pode ter incompatibilidades em Windows sem WSL | Baixo (P3 é story de menor prioridade) | Média | Escrever o script como bash compatível com WSL2; documentar que requer WSL2 ou ambiente Linux |

---

## 10. Critérios de Aceite Técnicos

Os critérios abaixo traduzem os "Success Criteria" do spec em verificações técnicas objetivas:

1. **Estrutura de diretórios**: Executar `ls -la` recursivo no repositório clonado e confirmar que todos os diretórios obrigatórios (`.claude/`, `apps/`, `infra/`, `.github/`, `mcp/`, `scripts/`) existem com os arquivos esperados.

2. **Docker Compose**: `docker compose up --build -f infra/docker/docker-compose.yml` (ou `docker compose up --build` se o arquivo estiver na raiz) conclui sem erros em máquina limpa.

3. **Health check do api-gateway**: `curl http://localhost:$API_PORT/health` retorna HTTP 200 com body JSON contendo `"status": "ok"`.

4. **Heartbeat do worker-service**: `docker logs worker-service` exibe ao menos uma linha de heartbeat no formato definido, sem linhas de erro.

5. **Contexto do agente**: Abrir o repositório no Claude Code e verificar que o agente cita o objetivo do projeto, as skills disponíveis ou as convenções de commit nas primeiras respostas, sem que o usuário forneça essas informações.

6. **Skills (stubs)**: Invocar `/deploy staging`, `/rollback` e `/health` no Claude Code e confirmar que o agente lê o arquivo correspondente e responde com mensagem de stub (não falha silenciosamente nem lança erro).

7. **Variáveis de ambiente**: Alterar `API_PORT` no `.env` para uma porta diferente, executar `docker compose up --build` novamente e confirmar que o `api-gateway` sobe na nova porta.

8. **Docker down**: `docker compose down` remove todos os containers sem erros.

9. **Multi-stage Dockerfile (P2)**: Executar `docker images` após o build e confirmar que a imagem final dos serviços usa base mínima e é menor que a imagem de build intermediária.

10. **Script de validação (P3)**: Remover um diretório obrigatório e executar `scripts/validate-structure.sh` — deve retornar exit code 1 e listar o diretório ausente. Restaurar o diretório e executar novamente — deve retornar exit code 0.
