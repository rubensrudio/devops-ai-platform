# =============================================================================
# infra/terraform/main.tf
# Feature: k8s-terraform | Semana 2
#
# Provisiona toda a infraestrutura Kubernetes no cluster minikube local.
# Espelha os manifests YAML em infra/k8s/ como recursos Terraform gerenciados,
# permitindo rastreamento de estado (tfstate) e preview de mudancas (plan).
#
# Pre-requisitos antes do apply:
#   1. minikube start --driver=docker
#   2. minikube addons enable ingress
#   3. eval $(minikube docker-env)
#   4. docker compose -f infra/docker/docker-compose.yml build
#   5. terraform init  (baixa provider hashicorp/kubernetes)
# =============================================================================

# -----------------------------------------------------------------------------
# Bloco terraform — versao do provider e backend
# O backend "local" persiste o tfstate em infra/terraform/terraform.tfstate
# (arquivo coberto pelo .gitignore — nao versionar).
# -----------------------------------------------------------------------------
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

# -----------------------------------------------------------------------------
# Provider kubernetes — conecta ao contexto "minikube" no kubeconfig do usuario.
# config_context garante que o Terraform nunca aplica no contexto errado
# (ex.: Docker Desktop K8s ou um cluster remoto).
# -----------------------------------------------------------------------------
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# =============================================================================
# 1. Namespace — devops-ai
#
# Isola todos os recursos desta plataforma. Espelha infra/k8s/namespace.yaml.
# Todos os demais recursos dependem deste namespace via depends_on.
# =============================================================================
resource "kubernetes_namespace" "devops_ai" {
  metadata {
    name = var.namespace
    labels = {
      feature = "k8s-terraform"
      week    = "2"
    }
  }
}

# =============================================================================
# 2. ConfigMap — platform-config
#
# Centraliza as variaveis de configuracao consumidas por api-gateway e
# worker-service via envFrom.configMapRef. Espelha infra/k8s/configmap.yaml.
# Valores derivados das variaveis Terraform (ver variables.tf):
#   - API_PORT            -> porta de escuta do api-gateway
#   - HEARTBEAT_INTERVAL  -> intervalo (s) de heartbeat do worker-service
#   - LOG_LEVEL           -> nivel de log (debug | info | warn | error)
# =============================================================================
resource "kubernetes_config_map" "platform_config" {
  metadata {
    name      = "platform-config"
    namespace = kubernetes_namespace.devops_ai.metadata[0].name
    labels = {
      feature = "k8s-terraform"
      week    = "2"
    }
  }

  # tostring() converte numeros para string conforme exigido pelo ConfigMap K8s
  data = {
    API_PORT           = tostring(var.api_port)
    HEARTBEAT_INTERVAL = tostring(var.heartbeat_interval)
    LOG_LEVEL          = var.log_level
  }

  depends_on = [kubernetes_namespace.devops_ai]
}

# =============================================================================
# 3. Deployment — api-gateway
#
# Espelha infra/k8s/api-gateway-deployment.yaml com configuracoes de:
#   - RollingUpdate (maxSurge=1, maxUnavailable=0) para zero-downtime deploys
#   - imagePullPolicy: Never  (imagem pre-buildada no daemon minikube)
#   - envFrom: ConfigMap platform-config
#   - Liveness probe: GET /health (garante reinicio automatico em crash)
#   - Readiness probe: GET /health (garante que so recebe trafego quando pronto)
#   - Resource requests/limits simbolicos para ambiente local (ver spec.md L-03)
#   - securityContext.runAsNonRoot: boas praticas de seguranca (OWASP K8s)
# =============================================================================
resource "kubernetes_deployment" "api_gateway" {
  metadata {
    name      = "api-gateway"
    namespace = kubernetes_namespace.devops_ai.metadata[0].name
    labels = {
      app     = "api-gateway"
      feature = "k8s-terraform"
      week    = "2"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "api-gateway"
      }
    }

    # RollingUpdate: substitui pods gradualmente — maxSurge=1 cria um pod extra
    # antes de remover o antigo; maxUnavailable=0 garante disponibilidade total.
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    template {
      metadata {
        labels = {
          app     = "api-gateway"
          feature = "k8s-terraform"
          week    = "2"
        }
      }

      spec {
        # runAsNonRoot + runAsUser numerico: necessario quando imagem usa usuario nomeado (node)
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
        }

        container {
          name  = "api-gateway"
          image = "api-gateway:${var.image_tag}"

          # Never: imagem deve estar pre-buildada no daemon minikube
          # (via eval $(minikube docker-env) && docker compose build)
          image_pull_policy = "Never"

          port {
            container_port = var.api_port
            protocol       = "TCP"
          }

          # Injeta todas as chaves do ConfigMap como variaveis de ambiente
          env_from {
            config_map_ref {
              name = kubernetes_config_map.platform_config.metadata[0].name
            }
          }

          # Requests: garantia minima de recursos para o scheduler.
          # Limits: teto maximo — protege outros pods no cluster local.
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          # Liveness probe: K8s reinicia o container se /health nao responder.
          # initialDelaySeconds=15 da tempo para a app inicializar antes da 1a check.
          liveness_probe {
            http_get {
              path = "/health"
              port = var.api_port
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            failure_threshold     = 3
          }

          # Readiness probe: pod so entra no pool de balanceamento apos responder.
          # initialDelaySeconds=5 e mais rapido pois o objetivo e liberar trafego cedo.
          readiness_probe {
            http_get {
              path = "/health"
              port = var.api_port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 2
          }
        }
      }
    }
  }

  # depends_on garante que namespace e configmap existam antes do deployment.
  # O ConfigMap deve existir para que o envFrom.configMapRef seja resolvido
  # corretamente durante o provisionamento (evita race condition).
  depends_on = [kubernetes_namespace.devops_ai, kubernetes_config_map.platform_config]
}

# =============================================================================
# 4. Service — api-gateway (ClusterIP)
#
# Expoe o Deployment api-gateway internamente no cluster.
# O Ingress (recurso 6) roteia trafego externo ate este Service.
# Espelha infra/k8s/api-gateway-service.yaml.
# ClusterIP: sem exposicao direta ao host — trafego externo apenas via Ingress.
# =============================================================================
resource "kubernetes_service" "api_gateway" {
  metadata {
    name      = "api-gateway"
    namespace = kubernetes_namespace.devops_ai.metadata[0].name
    labels = {
      app     = "api-gateway"
      feature = "k8s-terraform"
      week    = "2"
    }
  }

  spec {
    # Selector deve corresponder ao label "app" do Pod template do Deployment
    selector = {
      app = "api-gateway"
    }

    type = "ClusterIP"

    port {
      port        = var.api_port
      target_port = var.api_port
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_namespace.devops_ai]
}

# =============================================================================
# 5. Deployment — worker-service
#
# Espelha infra/k8s/worker-service-deployment.yaml.
# Diferencas em relacao ao api-gateway:
#   - Recreate: para em lote antes de recriar (sem necessidade de zero-downtime)
#   - Sem Service associado: worker nao recebe trafego externo
#   - Resources menores: cpu=50m/memory=64Mi (processo leve de heartbeat)
#   - Sem probes HTTP: worker nao expoe endpoint HTTP
# =============================================================================
resource "kubernetes_deployment" "worker_service" {
  metadata {
    name      = "worker-service"
    namespace = kubernetes_namespace.devops_ai.metadata[0].name
    labels = {
      app     = "worker-service"
      feature = "k8s-terraform"
      week    = "2"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "worker-service"
      }
    }

    # Recreate: para todos os pods antes de criar novos (worker stateless)
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app     = "worker-service"
          feature = "k8s-terraform"
          week    = "2"
        }
      }

      spec {
        # runAsNonRoot + runAsUser numerico: worker usa uid 1001 (usuario 'worker')
        security_context {
          run_as_non_root = true
          run_as_user     = 1001
        }

        container {
          name  = "worker-service"
          image = "worker-service:${var.image_tag}"

          # Never: imagem buildada localmente no daemon minikube
          image_pull_policy = "Never"

          # Injeta variaveis de configuracao via ConfigMap (HEARTBEAT_INTERVAL, LOG_LEVEL)
          env_from {
            config_map_ref {
              name = kubernetes_config_map.platform_config.metadata[0].name
            }
          }

          # Resources menores que api-gateway (worker apenas emite heartbeats)
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  # depends_on garante que namespace e configmap existam antes do deployment.
  # O ConfigMap deve existir para que o envFrom.configMapRef seja resolvido
  # corretamente durante o provisionamento (evita race condition).
  depends_on = [kubernetes_namespace.devops_ai, kubernetes_config_map.platform_config]
}

# =============================================================================
# 6. Ingress — api-gateway (nginx)
#
# Expoe o api-gateway externamente via nginx ingress controller.
# Espelha infra/k8s/ingress.yaml.
#
# PRE-REQUISITO: minikube addons enable ingress
#   O addon instala o nginx ingress controller no namespace ingress-nginx.
#   Sem ele, este recurso sera criado mas nenhum ADDRESS sera atribuido.
#
# CONFIGURACAO DE HOST LOCAL:
#   Para resolver "api-gateway.local" sem Header explicito, adicione ao /etc/hosts
#   do WSL2: echo "$(minikube ip) api-gateway.local" | sudo tee -a /etc/hosts
#   Ou use: curl -H "Host: api-gateway.local" http://$(minikube ip)/health
# =============================================================================
resource "kubernetes_ingress_v1" "api_gateway" {
  metadata {
    name      = "api-gateway"
    namespace = kubernetes_namespace.devops_ai.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
    labels = {
      app     = "api-gateway"
      feature = "k8s-terraform"
      week    = "2"
    }
  }

  spec {
    rule {
      # Host virtual: requer entrada em /etc/hosts ou uso do header Host:
      host = "api-gateway.local"

      http {
        path {
          # Prefix: roteia "/" e qualquer sub-path para o api-gateway
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              # Referencia o Service criado no recurso 4
              name = kubernetes_service.api_gateway.metadata[0].name
              port {
                number = var.api_port
              }
            }
          }
        }
      }
    }
  }

  # depends_on garante que o namespace e o Service existam antes de criar o Ingress.
  # O Service deve existir para que o backend do Ingress seja resolvido corretamente
  # e o nginx ingress controller consiga registrar as regras de roteamento.
  depends_on = [kubernetes_namespace.devops_ai, kubernetes_service.api_gateway]
}
