terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
  backend "local" {}
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "devops_ai" {
  metadata {
    name = var.namespace
    labels = {
      feature = "k8s-terraform"
      week    = "2"
    }
  }
}

# ---------------------------------------------------------------------------
# ConfigMap — plataforma
# ---------------------------------------------------------------------------
resource "kubernetes_config_map" "platform_config" {
  metadata {
    name      = "platform-config"
    namespace = kubernetes_namespace.devops_ai.metadata[0].name
    labels = {
      feature = "k8s-terraform"
      week    = "2"
    }
  }

  data = {
    API_PORT             = tostring(var.api_port)
    HEARTBEAT_INTERVAL   = tostring(var.heartbeat_interval)
    LOG_LEVEL            = var.log_level
  }

  depends_on = [kubernetes_namespace.devops_ai]
}

# ---------------------------------------------------------------------------
# Deployment — api-gateway
# ---------------------------------------------------------------------------
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

    strategy {
      type = "RollingUpdate"
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
        container {
          name              = "api-gateway"
          image             = "api-gateway:${var.image_tag}"
          image_pull_policy = "Never"

          port {
            container_port = var.api_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.platform_config.metadata[0].name
            }
          }

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

          liveness_probe {
            http_get {
              path = "/health"
              port = var.api_port
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            failure_threshold     = 3
          }

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

        security_context {
          run_as_non_root = true
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.platform_config]
}

# ---------------------------------------------------------------------------
# Service — api-gateway (ClusterIP)
# ---------------------------------------------------------------------------
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
    selector = {
      app = "api-gateway"
    }

    type = "ClusterIP"

    port {
      port        = var.api_port
      target_port = var.api_port
    }
  }

  depends_on = [kubernetes_deployment.api_gateway]
}

# ---------------------------------------------------------------------------
# Deployment — worker-service
# ---------------------------------------------------------------------------
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
        container {
          name              = "worker-service"
          image             = "worker-service:${var.image_tag}"
          image_pull_policy = "Never"

          env_from {
            config_map_ref {
              name = kubernetes_config_map.platform_config.metadata[0].name
            }
          }

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

        security_context {
          run_as_non_root = true
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.platform_config]
}
