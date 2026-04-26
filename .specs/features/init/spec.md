# Init — Estrutura Base da devops-ai-platform

## Problem Statement

Desenvolvedores que constroem portfólios técnicos avançados carecem de um projeto demonstrável end-to-end que integre agentes de IA (Claude Code) ao ciclo completo de DevOps — do commit ao pod rodando em cluster. A ausência dessa estrutura base impede o início de qualquer outra feature da plataforma. A feature `init` estabelece o esqueleto do repositório, os dois serviços de aplicação, a infra local (Docker + Compose) e o contexto do agente (CLAUDE.md + memória), tornando o ambiente funcional e pronto para as semanas seguintes.

## Goals

- [ ] Repositório inicializado com estrutura de diretórios padrão definida na proposta
- [ ] Dois serviços de aplicação (`api-gateway` e `worker-service`) funcionais e rodando localmente via Docker Compose
- [ ] Arquivo `CLAUDE.md` configurado com contexto do projeto para o agente Claude Code
- [ ] Estrutura de memória do agente criada (`.claude/memory/DECISIONS.md` e `LESSONS.md`)
- [ ] Estrutura de skills e agents criada com arquivos-base (stubs funcionais)
- [ ] `docker-compose.yml` sobe todos os serviços sem erros com um único comando

## Out of Scope

Explicitamente excluído. Documentado para evitar scope creep.

| Feature                             | Motivo da exclusão                                                                 |
| ----------------------------------- | ---------------------------------------------------------------------------------- |
| Kubernetes (k8s)                    | Semana 3 — depende da infra local estar estável primeiro                           |
| Terraform / LocalStack              | Semana 3 — IaC vem após Docker estar funcional                                     |
| GitHub Actions (CI/CD)              | Semana 4 — workflows dependem de repositório remoto configurado                    |
| MCP Servers customizados            | Semana 5 — complexidade máxima, vem por último                                     |
| claude-code-action no PR            | Semana 4 — requer GitHub Actions ativo                                             |
| Lógica de negócio real nos serviços | Os serviços são simples e funcionais; lógica avançada é irrelevante para o portfólio |
| Autenticação / segurança            | Fora do escopo da plataforma de portfólio neste momento                            |
| Observabilidade (logs, métricas)    | Pode ser adicionado como feature futura; não é bloqueante para o init              |

---

## User Stories

### P1: Estrutura do Repositório Inicializada ⭐ MVP

**User Story**: Como desenvolvedor que mantém o projeto, quero que o repositório siga a estrutura de diretórios definida na proposta para que qualquer colaborador (ou agente) entenda imediatamente onde cada artefato vive.

**Why P1**: Sem a estrutura base, nenhuma outra feature pode ser desenvolvida. É o pré-requisito absoluto de tudo.

**Acceptance Criteria**:

1. WHEN o repositório é clonado THEN a estrutura de diretórios SHALL corresponder exatamente ao layout definido na proposta (`.claude/`, `apps/`, `infra/`, `.github/`, `mcp/`, `skills/`)
2. WHEN um novo colaborador abre o repositório THEN SHALL encontrar um `README.md` raiz com descrição do projeto e instruções básicas de setup
3. WHEN qualquer diretório obrigatório está ausente THEN o script de validação SHALL reportar o diretório faltante com mensagem de erro clara

**Independent Test**: Clonar o repositório em máquina limpa e verificar que todos os diretórios listados na proposta existem com `ls -la` recursivo.

---

### P1: Serviços de Aplicação Rodando Localmente ⭐ MVP

**User Story**: Como desenvolvedor, quero subir `api-gateway` e `worker-service` com um único `docker compose up` para que eu possa validar a plataforma localmente antes de qualquer etapa de CI/CD.

**Why P1**: Os serviços são o núcleo demonstrável da plataforma. Sem eles rodando, não há nada para fazer deploy, revisar ou monitorar.

**Acceptance Criteria**:

1. WHEN `docker compose up` é executado na raiz do projeto THEN ambos os serviços SHALL subir sem erros e estar acessíveis em suas respectivas portas
2. WHEN o `api-gateway` está rodando THEN SHALL responder com status 200 em `GET /health`
3. WHEN o `worker-service` está rodando THEN SHALL logar uma mensagem de heartbeat a cada intervalo configurado (ex: a cada 10 segundos)
4. WHEN `docker compose down` é executado THEN todos os containers SHALL parar e ser removidos sem erros
5. WHEN a build de qualquer serviço falha THEN Docker SHALL exibir o erro de build com contexto suficiente para diagnóstico

**Independent Test**: Executar `docker compose up --build` e confirmar que `curl http://localhost:<porta>/health` retorna 200 para o api-gateway e que `docker logs worker-service` exibe heartbeats.

---

### P1: Contexto do Agente Configurado (CLAUDE.md + Memória) ⭐ MVP

**User Story**: Como agente Claude Code operando neste repositório, quero ter acesso a um `CLAUDE.md` com contexto completo do projeto e arquivos de memória persistente para que eu possa executar operações (deploy, rollback, health-check) com autonomia e rastreabilidade.

**Why P1**: O diferencial do projeto é o agente operar o fluxo inteiro. Sem o contexto configurado corretamente, o agente opera sem guardrails, sem histórico de decisões e sem skills definidas.

**Acceptance Criteria**:

1. WHEN o agente é iniciado no repositório THEN SHALL carregar `.claude/CLAUDE.md` com: objetivo do projeto, lista de skills disponíveis, referência aos agents, convenções de commit e instruções de segurança (ex: nunca fazer deploy em prod sem aprovação explícita)
2. WHEN o agente toma uma decisão relevante THEN SHALL registrar em `.claude/memory/DECISIONS.md` no formato `[AAAA-MM-DD] DECISÃO: ... | RACIOCÍNIO: ... | CONTEXTO: ...`
3. WHEN o agente encontra um padrão ou aprendizado relevante THEN SHALL registrar em `.claude/memory/LESSONS.md`
4. WHEN o arquivo `.claude/CLAUDE.md` não existe THEN o agente SHALL se recusar a executar operações destrutivas e solicitar que o arquivo seja criado

**Independent Test**: Abrir o repositório com Claude Code e verificar que o agente cita informações do `CLAUDE.md` nas primeiras respostas sem que o usuário precise informar contexto manualmente.

---

### P1: Skills e Agents Configurados com Stubs Funcionais ⭐ MVP

**User Story**: Como desenvolvedor, quero que as skills (`/deploy`, `/rollback`, `/health`) e os agents (`deploy-agent`, `review-agent`) estejam criados com stubs funcionais para que eu possa iterar sobre eles nas semanas seguintes sem precisar refatorar a estrutura.

**Why P1**: A estrutura de skills e agents define o contrato de interface do agente. Criar os stubs agora evita retrabalho estrutural nas semanas 2-5.

**Acceptance Criteria**:

1. WHEN o agente recebe o comando `/deploy <env>` THEN SHALL carregar `skills/deploy.md` e exibir mensagem indicando que a skill está em modo stub (não executa ainda)
2. WHEN o agente recebe o comando `/rollback` THEN SHALL carregar `skills/rollback.md` e exibir mensagem de stub
3. WHEN o agente recebe o comando `/health` THEN SHALL carregar `skills/health-check.md` e exibir status simulado
4. WHEN qualquer arquivo de skill ou agent está ausente THEN o agente SHALL reportar o arquivo faltante ao invés de falhar silenciosamente

**Independent Test**: Invocar cada um dos três comandos de skill no Claude Code e confirmar que o agente lê o arquivo correspondente e responde sem erro.

---

### P2: Dockerfiles com Multi-Stage Build

**User Story**: Como desenvolvedor, quero que os Dockerfiles usem multi-stage build para que as imagens de produção sejam menores e mais seguras, sem dependências de desenvolvimento incluídas.

**Why P2**: Boa prática que agrega valor ao portfólio, mas não bloqueia o funcionamento inicial. Os serviços sobem mesmo com Dockerfiles simples.

**Acceptance Criteria**:

1. WHEN `docker build` é executado em `Dockerfile.api` THEN a imagem final SHALL usar uma base mínima (ex: `node:alpine` ou `python:slim`) sem ferramentas de desenvolvimento
2. WHEN `docker build` é executado em `Dockerfile.worker` THEN o tamanho da imagem final SHALL ser menor que a imagem de build intermediária
3. WHEN as variáveis de ambiente necessárias não são passadas THEN o serviço SHALL falhar na inicialização com mensagem de erro descritiva (não silenciosamente)

**Independent Test**: Executar `docker images` após o build e comparar o tamanho da imagem final com uma versão sem multi-stage.

---

### P3: Script de Validação da Estrutura do Repositório

**User Story**: Como desenvolvedor ou agente de CI, quero um script que valide se a estrutura de diretórios e arquivos obrigatórios está correta para que erros de estrutura sejam detectados automaticamente.

**Why P3**: Conveniente para onboarding e CI, mas pode ser feito manualmente na fase inicial. Não bloqueia nenhuma outra feature.

**Acceptance Criteria**:

1. WHEN o script é executado em um repositório com estrutura completa THEN SHALL retornar exit code 0 e mensagem de sucesso
2. WHEN o script é executado em um repositório com arquivos ou diretórios faltando THEN SHALL retornar exit code 1 e listar cada item ausente

**Independent Test**: Remover um diretório obrigatório e executar o script para confirmar que ele detecta e reporta a ausência.

---

## Edge Cases

- WHEN `docker compose up` é executado sem Docker instalado THEN o sistema SHALL exibir mensagem de erro clara sobre dependência ausente (comportamento nativo do Docker CLI)
- WHEN a porta padrão do `api-gateway` já está em uso THEN Docker SHALL falhar com mensagem indicando conflito de porta, e o `docker-compose.yml` SHALL ter porta configurável via variável de ambiente
- WHEN `.claude/CLAUDE.md` existe mas está vazio THEN o agente SHALL tratar como ausente e solicitar configuração
- WHEN `docker compose up` é executado pela primeira vez sem imagens em cache THEN o tempo de build poderá ser elevado — o `README.md` SHALL documentar esse comportamento esperado
- WHEN o `worker-service` não consegue conectar a uma fila (se configurada) THEN SHALL logar o erro e continuar em modo degradado, não travar o container
- WHEN qualquer skill invocada referencia uma ferramenta não disponível no ambiente (ex: `kubectl` sem k8s configurado) THEN a skill SHALL verificar a disponibilidade da ferramenta e reportar o erro antes de tentar executar

---

## Requirement Traceability

| Requirement ID | Story                                          | Fase   | Status  |
| -------------- | ---------------------------------------------- | ------ | ------- |
| INIT-01        | P1: Estrutura do Repositório Inicializada      | Design | Pending |
| INIT-02        | P1: Estrutura do Repositório Inicializada      | Design | Pending |
| INIT-03        | P1: Estrutura do Repositório Inicializada      | Design | Pending |
| INIT-04        | P1: Serviços de Aplicação Rodando Localmente   | Design | Pending |
| INIT-05        | P1: Serviços de Aplicação Rodando Localmente   | Design | Pending |
| INIT-06        | P1: Serviços de Aplicação Rodando Localmente   | Design | Pending |
| INIT-07        | P1: Serviços de Aplicação Rodando Localmente   | Design | Pending |
| INIT-08        | P1: Serviços de Aplicação Rodando Localmente   | Design | Pending |
| INIT-09        | P1: Contexto do Agente Configurado             | Design | Pending |
| INIT-10        | P1: Contexto do Agente Configurado             | Design | Pending |
| INIT-11        | P1: Contexto do Agente Configurado             | Design | Pending |
| INIT-12        | P1: Contexto do Agente Configurado             | Design | Pending |
| INIT-13        | P1: Skills e Agents com Stubs Funcionais       | Design | Pending |
| INIT-14        | P1: Skills e Agents com Stubs Funcionais       | Design | Pending |
| INIT-15        | P1: Skills e Agents com Stubs Funcionais       | Design | Pending |
| INIT-16        | P1: Skills e Agents com Stubs Funcionais       | Design | Pending |
| INIT-17        | P2: Dockerfiles com Multi-Stage Build          | -      | Pending |
| INIT-18        | P2: Dockerfiles com Multi-Stage Build          | -      | Pending |
| INIT-19        | P2: Dockerfiles com Multi-Stage Build          | -      | Pending |
| INIT-20        | P3: Script de Validação da Estrutura           | -      | Pending |
| INIT-21        | P3: Script de Validação da Estrutura           | -      | Pending |

**Cobertura:** 21 total, 0 mapeados para tasks, 21 não mapeados

---

## Success Criteria

Como saber que a feature `init` está concluída:

- [ ] `git clone` + `docker compose up --build` funciona em máquina limpa sem passos manuais adicionais
- [ ] `curl http://localhost:<porta>/health` retorna HTTP 200 para o `api-gateway`
- [ ] `docker logs worker-service` exibe heartbeats sem erros
- [ ] Claude Code abre o repositório e cita informações do `CLAUDE.md` sem input adicional do usuário
- [ ] Os três comandos de skill (`/deploy staging`, `/rollback`, `/health`) são reconhecidos pelo agente e retornam resposta de stub sem erro
- [ ] A estrutura de diretórios bate exatamente com o layout da proposta

---

## Premissas e Lacunas

| ID       | Tipo      | Descrição                                                                                                                                                         |
| -------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LACUNA-1 | Tecnologia | [LACUNA: A linguagem/framework do `api-gateway` não está definida com precisão — a proposta menciona "Node.js/FastAPI" (tecnologias diferentes). Qual é a escolha final?] |
| LACUNA-2 | Tecnologia | [LACUNA: A linguagem/framework do `worker-service` não está especificada. Qual stack e qual sistema de fila ele consome (RabbitMQ, SQS, Redis Streams)?]           |
| LACUNA-3 | Ambiente  | [LACUNA: O ambiente de desenvolvimento alvo não está definido — Mac, Linux ou Windows com WSL? Isso impacta comandos do `docker-compose.yml` e scripts de setup.] |
| LACUNA-4 | Portfólio | [LACUNA: O repositório será público no GitHub desde o início ou somente após o polish da semana 6? Isso impacta decisões sobre secrets e `.gitignore`.]           |
