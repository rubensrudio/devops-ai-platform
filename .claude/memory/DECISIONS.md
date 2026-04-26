# DECISIONS.md — Registro de Decisoes Arquiteturais

Este arquivo registra as decisoes arquiteturais tomadas durante o desenvolvimento
da devops-ai-platform. Cada entrada deve seguir o formato abaixo.

## Formato de Registro

```
[AAAA-MM-DD] DECISAO: <decisao tomada> | RACIOCINIO: <justificativa objetiva> | CONTEXTO: <situacao que motivou a decisao>
```

Regras:
- Uma decisao por linha
- Mantenha a ordem cronologica (mais recente no final)
- Seja conciso: cada campo deve ter no maximo 2 linhas
- Nao edite decisoes ja registradas — adicione uma nova entrada de revisao se necessario

---

## Decisoes Registradas

[2026-04-26] DECISAO: docker-compose.yml fica em infra/docker/ e nao na raiz do repositorio | RACIOCINIO: A pasta infra/ e o container canonico de artefatos de infraestrutura; manter o Compose ali e coerente com a estrutura futura (Terraform, manifests Kubernetes virao na Semana 3) e evita poluir a raiz com arquivos de infra | CONTEXTO: DA-01 — decisao tomada durante o planejamento da feature init para garantir escalabilidade da estrutura de diretorios antes da implementacao dos primeiros servicos
[2026-04-26] DECISAO: usar minikube como runtime Kubernetes local (em vez de kind) | RACIOCINIO: integracao nativa com Docker Desktop via --driver=docker; eval $(minikube docker-env) elimina necessidade de registry externo; minikube addons enable ingress provisiona nginx com um comando; maior familiaridade didatica para portfolio | CONTEXTO: DA-02 — escolha da ferramenta K8s local durante planejamento da feature k8s-terraform (Semana 2)
[2026-04-26] DECISAO: usar Terraform (provider kubernetes) como mecanismo primario de provisionamento K8s, mantendo manifests raw em infra/k8s/ como documentacao executavel secundaria | RACIOCINIO: objetivo do portfolio e demonstrar IaC; terraform plan oferece preview auditavel; tfstate detecta drift; antecipa estrutura da Semana futura com provider cloud; manifests raw preservam capacidade de operar sem Terraform | CONTEXTO: DA-03 — decisao de tooling IaC durante planejamento da feature k8s-terraform (Semana 2)
