# Define DigitalOcean provider
provider "digitalocean" {
  token = var.DO_TOKEN
}

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.my_cluster.endpoint
    token                  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.my_cluster.endpoint
  token                  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)
}


# Define Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "my_cluster" {
  name    = "right-purchase-cluster"
  region  = "nyc3"        # For complete list run `doctl kubernetes options regions`
  version = "1.29.1-do.0" # For complete list run `doctl kubernetes options versions`

  node_pool {
    name       = "right-purchase-node-pool"
    size       = "s-1vcpu-2gb" # For complete list run `doctl kubernetes options sizes`
    node_count = 1
    tags       = ["right-purchase-tag"]
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 3
  }
}

resource "kubernetes_persistent_volume_claim" "traefik_pvc" {
  metadata {
    name = "traefik-pvc"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "128Mi"
      }
    }
  }
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "26.0.0"
  values = [
    file("${path.module}/values.yaml")
  ]

  set {
    name  = "service.name"
    value = "traefik-load-balancer"
  }

  set {
    name  = "persistence.existingClaim"
    value = kubernetes_persistent_volume_claim.traefik_pvc.metadata.0.name
  }

}

data "kubernetes_service" "traefik" {
  metadata {
    name = helm_release.traefik.metadata.0.name
  }
}

resource "digitalocean_domain" "root_domain" {
  name = var.DNS_NAME
}

resource "digitalocean_record" "root_domain" {
  domain = digitalocean_domain.root_domain.name
  type   = "A"
  name   = "@" # "@" for root domain
  value  = data.kubernetes_service.traefik.status.0.load_balancer.0.ingress.0.ip
  ttl    = 1800 # TTL in seconds (adjust as needed)
}

resource "digitalocean_record" "www_subdomain" {
  domain = digitalocean_domain.root_domain.name
  type   = "CNAME"
  name   = "www"
  value  = "${digitalocean_domain.root_domain.name}."
  ttl    = 1800 # TTL in seconds (adjust as needed)
}
