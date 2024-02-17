output "cluster_name" {
  description = "The name of the Kubernetes cluster created"
  value       = digitalocean_kubernetes_cluster.my_cluster.name
}

output "helm_api_gateway_name" {
  description = "The name of the API Gateway service"
  value       = helm_release.traefik.name
}
