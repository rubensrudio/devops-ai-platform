# devops-ai-platform

A portfolio project integrating AI agents (Claude Code) into a complete DevOps cycle — from commit to running container, with deploy, rollback, and health-check orchestrated by the agent.

The repository contains two services (`api-gateway` and `worker-service`) orchestrated via Docker Compose, the Claude Code agent context (`.claude/`), and skill/agent stubs for future expansion.

---

## Prerequisites

| Tool | Min version | Purpose |
|------|------------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | 4.x+ | Run containers locally |
| WSL2 (Windows) | Any | Docker Desktop backend on Windows |
| [Claude Code CLI](https://docs.anthropic.com/claude-code) | Latest | Interact with the agent |
| Git | 2.x+ | Clone and version the repository |
| [minikube](https://minikube.sigs.k8s.io/docs/start/) | v1.32+ | Local Kubernetes cluster |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | v1.29+ | Kubernetes CLI |
| [terraform](https://developer.hashicorp.com/terraform/install) | v1.7+ | Infrastructure as Code |

Shell scripts (`.sh`) require bash — use WSL2 on Windows. minikube, kubectl and terraform must be installed inside WSL2.

---

## Repository structure

```
devops-ai-platform/
├── .claude/
│   ├── CLAUDE.md               # Agent context — loaded automatically by Claude Code
│   ├── memory/
│   │   ├── DECISIONS.md        # Architectural decisions log
│   │   └── LESSONS.md          # Agent learnings
│   ├── agents/
│   │   ├── deploy-agent.md     # Deploy agent stub
│   │   └── review-agent.md     # Review agent stub
│   └── skills/
│       ├── deploy.md           # /deploy skill (real for env local)
│       ├── rollback.md         # /rollback skill stub
│       └── health-check.md     # /health skill stub
├── apps/
│   ├── api-gateway/            # Node.js/Express — GET /health
│   │   ├── src/
│   │   └── Dockerfile
│   └── worker-service/         # Python worker with heartbeat loop
│       ├── src/
│       └── Dockerfile
├── infra/
│   ├── docker/
│   │   └── docker-compose.yml  # Local orchestration (Docker Compose)
│   ├── k8s/                    # Raw Kubernetes manifests (namespace devops-ai)
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── api-gateway-deployment.yaml
│   │   ├── api-gateway-service.yaml
│   │   ├── worker-service-deployment.yaml
│   │   └── ingress.yaml
│   └── terraform/              # Infrastructure as Code (hashicorp/kubernetes provider)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── .github/                    # Placeholder for GitHub Actions
├── mcp/                        # Placeholder for MCP Servers
├── scripts/
│   ├── validate-structure.sh   # Validates repository directory structure
│   ├── smoke-test.sh           # End-to-end integration test (Docker Compose)
│   └── k8s-setup.sh            # Kubernetes local environment setup (minikube)
├── .env.example                # Environment variables template
└── README.md
```

---

## Setup

```bash
git clone https://github.com/rubensrudio/devops-ai-platform.git
cd devops-ai-platform
cp .env.example .env
```

Never commit `.env` — it is gitignored. Only `.env.example` is versioned.

---

## Running

All commands run from the **repository root**.

```bash
# Build and start
docker compose -f infra/docker/docker-compose.yml up --build

# Detached mode
docker compose -f infra/docker/docker-compose.yml up --build -d

# Stop and remove containers
docker compose -f infra/docker/docker-compose.yml down
```

> First build may take several minutes — Docker pulls base images and installs dependencies. Subsequent builds use the layer cache.

---

## Verifying the services

**api-gateway health check:**

```bash
curl http://localhost:3000/health
```

Expected response (HTTP 200):

```json
{
  "status": "ok",
  "service": "api-gateway",
  "timestamp": "2026-04-26T10:00:00.000Z"
}
```

**worker-service heartbeat:**

```bash
docker logs worker-service
```

Expected output (one line every 10 seconds by default):

```
[2026-04-26T10:00:00Z] [worker-service] heartbeat — status: ok
```

---

## Kubernetes Setup

> Requires WSL2 with minikube v1.32+, kubectl v1.29+ and terraform v1.7+ installed inside WSL2.

Run the automated setup script from the repository root (inside WSL2):

```bash
bash scripts/k8s-setup.sh
```

The script will:
1. Verify prerequisites (minikube, kubectl, terraform, docker)
2. Start minikube with `--driver=docker` and enable the nginx ingress addon
3. Configure the Docker context to the minikube daemon
4. Build service images inside the minikube daemon
5. Run `terraform init` and `terraform apply -auto-approve`
6. Wait for all pods to reach `Ready` state (timeout: 120s)
7. Validate the api-gateway endpoint via Ingress (HTTP 200)

**Validate running pods:**

```bash
kubectl get pods -n devops-ai
```

Expected output (both pods Running and Ready):

```
NAME                              READY   STATUS    RESTARTS   AGE
api-gateway-<hash>                1/1     Running   0          1m
worker-service-<hash>             1/1     Running   0          1m
```

**Health check via Ingress:**

```bash
curl -H "Host: api-gateway.local" http://$(minikube ip)/health
```

Expected response (HTTP 200):

```json
{"status":"ok","service":"api-gateway","timestamp":"..."}
```

---

## Commands

| Command | Description |
|---------|-------------|
| `docker compose -f infra/docker/docker-compose.yml up --build` | Build and start all services |
| `docker compose -f infra/docker/docker-compose.yml up --build -d` | Start in background |
| `docker compose -f infra/docker/docker-compose.yml down` | Stop and remove containers |
| `docker compose -f infra/docker/docker-compose.yml logs -f` | Follow logs from all services |
| `docker logs api-gateway` | api-gateway logs |
| `docker logs worker-service` | worker-service logs |
| `bash scripts/validate-structure.sh` | Validate repository structure |
| `bash scripts/smoke-test.sh` | Run end-to-end integration test |

---

## Agent skills

Open the repository with Claude Code CLI and invoke:

| Command | Description | Status | Reference file |
|---------|-------------|--------|----------------|
| `/deploy local` | Deploy to local Kubernetes cluster via `terraform apply` | **Real** | `.claude/skills/deploy.md` |
| `/deploy staging` | Deploy to staging environment | Placeholder (Week 4) | `.claude/skills/deploy.md` |
| `/deploy production` | Deploy to production (requires explicit confirmation) | Guardrail | `.claude/skills/deploy.md` |
| `/rollback` | Roll back to previous version | Stub | `.claude/skills/rollback.md` |
| `/health` | Check service status | Stub | `.claude/skills/health-check.md` |

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_PORT` | `3000` | Port exposed by `api-gateway` |
| `HEARTBEAT_INTERVAL` | `10` | Worker heartbeat interval in seconds |
| `LOG_LEVEL` | `info` | Log level (`debug`, `info`, `warn`, `error`) |

If port `3000` is already in use, set `API_PORT=4000` in `.env` before running.
