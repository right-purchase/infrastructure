output "cluster_name" {
  description = "The name of the Kubernetes cluster created"
  value       = digitalocean_kubernetes_cluster.my_cluster.name
}

output "helm_api_gateway_name" {
  description = "The name of the API Gateway service"
  value       = helm_release.traefik.name
}

output "helm_api_gateway_load_balancer_ip" {
  description = "The IP address of the API Gateway service"
  value       = data.kubernetes_service.traefik.status.0.load_balancer.0.ingress.0.ip
}

output "domain_name" {
  description = "The domain name for the API Gateway service"
  value       = var.DNS_NAME
}
