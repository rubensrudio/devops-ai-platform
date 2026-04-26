# Skill: /deploy

## Descricao

A skill `/deploy` orquestra o processo completo de deploy de um servico para um ambiente
alvo. Ela valida pre-requisitos, aplica a infraestrutura via Terraform e verifica a saude
dos servicos apos o deploy.

## Uso

```
/deploy <env>
```

### Parametros aceitos

| Parametro     | Tipo   | Obrigatorio | Valores aceitos                  | Descricao                                                       |
|---------------|--------|-------------|----------------------------------|-----------------------------------------------------------------|
| `<env>`       | string | Sim         | `local`, `staging`, `production` | Ambiente alvo do deploy                                         |

### Exemplos

```
/deploy local
/deploy staging
/deploy production
```

> AVISO DE SEGURANCA: Deploy em `production` requer confirmacao explicita do usuario.
> O agente NUNCA executa deploy em producao sem confirmacao verbal na mesma sessao.

---

## Checklist de Pre-requisitos

Executar OBRIGATORIAMENTE antes de qualquer acao de deploy. Se qualquer verificacao
falhar, reportar a ferramenta/estado ausente com instrucao de resolucao e abortar.

### 1. kubectl disponivel

```bash
kubectl version --client
```

Falha esperada se ausente:
```
erro: kubectl nao encontrado no PATH.
Resolucao: instale kubectl >= v1.29 — https://kubernetes.io/docs/tasks/tools/
```

### 2. Cluster minikube rodando

```bash
minikube status
```

Resultado esperado: `host: Running`, `kubelet: Running`, `apiserver: Running`.

Falha esperada se parado:
```
erro: minikube nao esta em execucao (status: Stopped).
Resolucao: execute 'minikube start --driver=docker' para iniciar o cluster.
```

### 3. Imagens presentes no daemon minikube

```bash
docker images | grep -E "api-gateway|worker-service"
```

Resultado esperado: pelo menos uma linha para cada imagem.

Falha esperada se ausentes:
```
erro: imagens api-gateway e/ou worker-service nao encontradas no daemon minikube.
Resolucao: execute 'eval $(minikube docker-env)' e depois
           'docker compose -f infra/docker/docker-compose.yml build'
           para construir as imagens no contexto do cluster.
```

### 4. Configuracao Terraform valida

```bash
terraform -chdir=infra/terraform validate
```

Resultado esperado: `Success! The configuration is valid.`

Falha esperada se invalida:
```
erro: terraform validate falhou — verifique os arquivos em infra/terraform/.
Resolucao: corrija os erros HCL reportados pelo validate antes de prosseguir.
           Se o diretorio .terraform/ nao existir, execute primeiro:
           terraform -chdir=infra/terraform init
```

---

## Comportamento por Ambiente

### /deploy local

Executa o fluxo de deploy real no cluster minikube local via Terraform.

**Fluxo de execucao (8 etapas):**

```
Etapa 1 — Checklist de pre-requisitos
  Executar as 4 verificacoes descritas na secao anterior.
  Qualquer falha: reportar erro + instrucao de resolucao + abortar.

Etapa 2 — Configurar contexto kubectl
  kubectl config use-context minikube

Etapa 3 — Aplicar infraestrutura via Terraform
  terraform -chdir=infra/terraform apply -auto-approve \
    -var="api_port=${API_PORT:-3000}" \
    -var="image_tag=latest"

Etapa 4 — Aguardar rollout do api-gateway
  kubectl rollout status deployment/api-gateway -n devops-ai --timeout=120s

Etapa 5 — Aguardar rollout do worker-service
  kubectl rollout status deployment/worker-service -n devops-ai --timeout=120s

Etapa 6 — Verificar saude via Ingress
  curl -H "Host: api-gateway.local" http://$(minikube ip)/health
  Resultado esperado: HTTP 200

Etapa 7 — Registrar decisao em DECISIONS.md
  Adicionar entrada em .claude/memory/DECISIONS.md no formato:
  [data] DECISAO: deploy local executado via /deploy local | RACIOCINIO: <resultado> | CONTEXTO: Semana 2, k8s-terraform

Etapa 8 — Reportar resultado
  Exibir saida de: kubectl get pods -n devops-ai
  Reportar sucesso ou falha com contexto do que ocorreu em cada etapa.
```

### /deploy staging

Este ambiente e um placeholder para implementacao futura.

```
[deploy.md] /deploy staging invocado.
STATUS: placeholder — implementacao planejada para Semana 4 (CI/CD com GitHub Actions).
Nenhuma acao de infra foi executada.
```

### /deploy production

GUARDRAIL OBRIGATORIO: este ambiente requer confirmacao explicita antes de qualquer acao.

Ao receber `/deploy production`, o agente DEVE exibir a mensagem abaixo e aguardar
confirmacao. NENHUMA acao de infra pode ser executada antes da confirmacao.

```
AGUARDANDO CONFIRMACAO: Digite exatamente 'SIM, confirmo deploy em production' para continuar.

Voce solicitou deploy em PRODUCTION.
Esta e uma operacao destrutiva/irreversivel que afeta o ambiente de producao.
O agente ira aguardar sua confirmacao explicita antes de executar qualquer acao.
```

Somente apos receber a string exata `SIM, confirmo deploy em production` na mesma
sessao o agente deve prosseguir. Qualquer outra resposta deve ser tratada como
cancelamento.

---

## Verificacao Individual de Pre-requisitos

Para diagnosticar o ambiente antes de executar o deploy, voce pode rodar cada
verificacao separadamente:

```bash
# Verificar kubectl
kubectl version --client
# Esperado: Client Version: v1.29+

# Verificar minikube
minikube status
# Esperado: host: Running | kubelet: Running | apiserver: Running

# Verificar docker (minikube)
docker images | grep -E "api-gateway|worker-service"
# Esperado: pelo menos uma linha para cada imagem

# Verificar terraform
terraform -chdir=infra/terraform validate
# Esperado: Success! The configuration is valid.

# Verificar contexto kubectl ativo
kubectl config current-context
# Esperado: minikube
```

---

## Tratamento de Erros

| Etapa | Erro possivel                         | Acao do agente                                                  |
|-------|---------------------------------------|-----------------------------------------------------------------|
| 1     | kubectl nao encontrado                | Exibir URL de instalacao e abortar                              |
| 1     | minikube parado                       | Exibir comando de inicio e abortar                              |
| 1     | imagens ausentes no daemon            | Exibir comando de build e abortar                               |
| 1     | terraform validate falha              | Exibir erro do validate e abortar                               |
| 3     | terraform apply falha                 | Exibir output completo do apply e abortar                       |
| 4/5   | rollout timeout (120s)                | Executar `kubectl describe pod` e `kubectl logs` antes de falhar|
| 6     | curl retorna != HTTP 200              | Reportar codigo recebido e sugerir `kubectl logs deploy/api-gateway -n devops-ai` |

---

## Dependencias

- Cluster minikube operacional (`minikube start --driver=docker`)
- nginx ingress controller habilitado (`minikube addons enable ingress`)
- Imagens buildadas no daemon minikube (`eval $(minikube docker-env)` + build)
- Terraform inicializado (`terraform -chdir=infra/terraform init`)
- Manifests em `infra/terraform/` e `infra/k8s/` presentes e validos
