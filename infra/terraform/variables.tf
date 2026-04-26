variable "api_port" {
  description = "Porta em que o api-gateway escuta dentro do container"
  type        = number
  default     = 3000
}

variable "heartbeat_interval" {
  description = "Intervalo em segundos entre heartbeats do worker-service"
  type        = number
  default     = 10
}

variable "image_tag" {
  description = "Tag das imagens Docker dos servicos"
  type        = string
  default     = "latest"
}

variable "namespace" {
  description = "Namespace Kubernetes onde os recursos serao criados"
  type        = string
  default     = "devops-ai"
}

variable "log_level" {
  description = "Nivel de log dos servicos: debug | info | warn | error"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "log_level deve ser debug, info, warn ou error."
  }
}

variable "image_registry" {
  description = "Registry de imagens Docker (ex: ghcr.io/rubensrudio). Vazio = imagem local minikube."
  type        = string
  default     = ""
}
