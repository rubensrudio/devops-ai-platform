# Skill: /deploy

## Descricao

A skill `/deploy` orquestra o processo completo de deploy de um servico para um ambiente
alvo. Ela valida pre-requisitos, constroi imagens Docker, aplica manifestos de infra e
verifica a saude do servico apos o deploy.

## Uso

```
/deploy <env>
```

### Parametros

| Parametro | Tipo     | Obrigatorio | Valores aceitos          | Descricao                                      |
|-----------|----------|-------------|--------------------------|------------------------------------------------|
| `<env>`   | string   | Sim         | `staging`, `production`  | Ambiente alvo do deploy                        |

### Exemplos

```
/deploy staging
/deploy production
```

> AVISO DE SEGURANCA: Deploy em `production` requer aprovacao explicita do usuario.
> O agente NUNCA executa deploy em producao sem confirmacao verbal na mesma sessao.

---

## STATUS: MODO STUB

**Esta skill esta em modo stub — nao executa ainda.**

Ao receber o comando `/deploy <env>`, o agente deve exibir esta mensagem e encerrar
sem executar nenhuma acao de infra:

```
[deploy.md] Skill /deploy invocada para o ambiente: <env>
STATUS: modo stub — nao executa ainda.
Implementacao real planejada para Semana 3 (Kubernetes + Terraform).
Nenhuma acao de infra foi executada.
```

---

## Verificacao de Disponibilidade de Ferramentas

Antes de qualquer execucao real (fora do modo stub), esta skill deve verificar a
disponibilidade das ferramentas abaixo. Se qualquer ferramenta estiver ausente,
reportar o erro e encerrar sem executar o deploy.

| Ferramenta  | Comando de verificacao      | Status nesta fase  | Acao se ausente                          |
|-------------|-----------------------------|--------------------|------------------------------------------|
| `kubectl`   | `kubectl version --client`  | NAO DISPONIVEL     | Reportar ausencia e encerrar             |
| `docker`    | `docker version`            | Verificar          | Reportar ausencia e encerrar             |
| `helm`      | `helm version`              | NAO DISPONIVEL     | Reportar ausencia e encerrar             |

> Nota de fase: `kubectl` e `helm` nao estao configurados no ambiente de desenvolvimento
> inicial (Semana 1). Eles serao provisionados na Semana 3 junto com o cluster Kubernetes.

---

## Implementacao Futura (Placeholder)

Quando esta skill for implementada completamente (Semana 3+), o fluxo sera:

```
1. Validar parametro <env> (staging | production)
2. Se <env> == production: solicitar confirmacao explicita do usuario
3. Verificar disponibilidade de kubectl, docker, helm
4. Executar docker compose build (ou docker buildx para multi-arch)
5. Push das imagens para o registry configurado
6. Aplicar manifestos Kubernetes via kubectl apply -f infra/k8s/<env>/
7. Aguardar rollout: kubectl rollout status deployment/<servico> -n <namespace>
8. Verificar saude: GET /health nos servicos deployados
9. Registrar resultado em .claude/memory/DECISIONS.md
10. Reportar status final ao usuario
```

Dependencias que precisam estar prontas antes da implementacao:
- [ ] Cluster Kubernetes configurado (Semana 3)
- [ ] Terraform / LocalStack para infra cloud (Semana 3)
- [ ] GitHub Actions com secrets configurados (Semana 4)
- [ ] Registry de imagens Docker definido e acessivel
- [ ] Manifestos Kubernetes em `infra/k8s/` criados
