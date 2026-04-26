output "api_gateway_endpoint" {
  description = "Endpoint do api-gateway via Ingress nginx (requer minikube ip)"
  value       = "http://<minikube-ip> (Host: api-gateway.local) — execute: minikube ip"
}

output "namespace" {
  description = "Namespace Kubernetes onde os servicos foram deployados"
  value       = var.namespace
}

output "api_gateway_service_name" {
  description = "Nome do Service Kubernetes do api-gateway"
  value       = kubernetes_service.api_gateway.metadata[0].name
}
