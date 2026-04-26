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
