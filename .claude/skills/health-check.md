# Skill: /health

## Descrição

Verifica o status de saude dos servicos da plataforma e retorna um relatorio
consolidado com o estado de cada componente.

## Uso

```
/health [<service>]
```

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição |
|-----------|-------------|-----------|
| `service` | Não | Nome do servico especifico (ex: `api-gateway`, `worker-service`). Se omitido, verifica todos os servicos. |

## Status

> **STUB — Status simulado com valores hardcoded.**
>
> Esta e uma versao stub criada na Semana 1 (feature/init).
> A integracao real com endpoints HTTP e metricas de container sera
> implementada em semana futura quando os servicos estiverem rodando
> via Docker Compose e Kubernetes.

## Status simulado (hardcoded — Semana 1)

Quando invocado, o agente deve exibir o seguinte relatorio de status simulado:

```
[HEALTH CHECK] Relatorio de saude da plataforma
Timestamp: <timestamp-atual>
Modo: stub (simulado — valores hardcoded)

Servicos:
  api-gateway    : ok
  worker-service : ok

Infraestrutura:
  docker-compose : nao verificado (stub)
  rede interna   : nao verificado (stub)

AVISO: Este relatorio e simulado. A integracao real sera implementada
em semana futura com verificacao HTTP real em GET /health de cada servico.
```

## Integracao real (prevista para semana futura)

> **Nota:** A integracao com endpoints reais sera implementada quando:
> - `api-gateway` estiver rodando via Docker Compose (Semana 1, TASK-006)
> - Health checks HTTP estiverem acessiveis em `GET /health`
> - Metricas de container (`docker inspect`, `kubectl get pods`) estiverem disponiveis

## Placeholder para implementacao real

```
# TODO (pos-TASK-006 e TASK-010): Implementar verificacao real de saude
#
# Passos previstos:
#   1. Para cada servico configurado:
#      a. Executar: curl -sf http://localhost:<porta>/health
#      b. Verificar HTTP status code (200 = ok, outros = degradado/down)
#      c. Parsear JSON response: {"status": "ok"|"degraded", "service": "...", "timestamp": "..."}
#   2. Para verificacao via Docker:
#      a. docker inspect --format='{{.State.Health.Status}}' <container>
#   3. Para verificacao via Kubernetes (Semana 3+):
#      a. kubectl get pods -n <namespace> -o wide
#   4. Consolidar resultados e exibir relatorio formatado
#   5. Se qualquer servico estiver degradado, sugerir /rollback
#
# Ferramentas necessarias:
#   - curl (disponivel)
#   - docker CLI (disponivel apos TASK-010)
#   - kubectl (disponivel a partir da Semana 3)
```

## Guardrails

- Se nenhum servico estiver configurado ainda, informar que o stub esta ativo
- NUNCA reportar servicos como "ok" em modo real se o endpoint nao responder
- Registrar falhas criticas em `.claude/memory/DECISIONS.md`

## Relacionado

- Skill `/deploy` — verificar saude apos deploy
- Skill `/rollback` — acionar rollback se health check falhar
- Agent `deploy-agent.md` — agente que usa `/health` para validar pos-deploy
