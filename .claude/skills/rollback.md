# Skill: /rollback

## Descrição

Executa o rollback do serviço especificado para a versão anterior estável.
Esta skill é invocada quando um deploy causa instabilidade ou falha nos health checks.

## Uso

```
/rollback [<service>] [<version>]
```

**Parâmetros:**

| Parâmetro | Obrigatório | Descrição |
|-----------|-------------|-----------|
| `service` | Não | Nome do serviço a ser revertido (ex: `api-gateway`, `worker-service`). Se omitido, aplica rollback em todos os serviços. |
| `version` | Não | Versão alvo do rollback (ex: `v1.2.3`, `sha:abc1234`). Se omitida, reverte para a última versão estável registrada. |

## Status

> **STUB — Esta skill NAO executa operacoes reais.**
>
> Esta e uma versao stub criada na Semana 1 (feature/init).
> A implementacao real sera desenvolvida em semana futura quando a
> infraestrutura de Kubernetes e pipelines CI/CD estiver configurada.
>
> Ao receber o comando `/rollback`, o agente deve exibir esta mensagem e
> aguardar instrucoes manuais do operador.

## Comportamento esperado (modo stub)

Quando invocado, o agente deve responder:

```
[ROLLBACK] Skill em modo stub — nenhuma operacao foi executada.
Implementacao real pendente para Semana 3 (infra Kubernetes).
Para rollback manual, consulte o runbook em docs/runbooks/rollback.md (ainda nao criado).
```

## Placeholder para implementacao real

```
# TODO (Semana 3+): Implementar logica de rollback real
#
# Passos previstos:
#   1. Verificar historico de deploys em .claude/memory/DECISIONS.md
#   2. Identificar a versao anterior estavel
#   3. Executar: kubectl rollout undo deployment/<service> -n <namespace>
#      OU: docker compose pull <versao-anterior> && docker compose up -d
#   4. Aguardar health checks passarem (usar skill /health para verificar)
#   5. Registrar rollback em .claude/memory/DECISIONS.md no formato:
#      [AAAA-MM-DD] DECISAO: rollback <service> para <version> |
#      RAZAO: <motivo> | CONTEXTO: <situacao que motivou>
#
# Ferramentas necessarias (nao disponíveis no init):
#   - kubectl (disponível a partir da Semana 3)
#   - Historico de imagens Docker registrado
#   - Acesso ao cluster Kubernetes
```

## Guardrails de seguranca

- NUNCA executar rollback em ambiente de producao sem aprovacao explícita do usuario
- SEMPRE registrar a operacao em `.claude/memory/DECISIONS.md` antes de executar
- SEMPRE verificar health checks apos o rollback com `/health`
- Se o servico alvo nao for reconhecido, reportar o erro e nao executar

## Relacionado

- Skill `/deploy` — skill de deploy que pode ter originado a necessidade de rollback
- Skill `/health` — verificacao de saude apos rollback
- Agent `deploy-agent.md` — agente responsavel por orquestrar deploys e rollbacks
