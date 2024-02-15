# Define DigitalOcean provider
provider "digitalocean" {
  token = var.DO_TOKEN
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

# Define Kubernetes provider
provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.my_cluster.endpoint
  token                  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.my_cluster.endpoint
    token                  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)
  }
}

# Allocate reserved IP if it doesn't exist, or retrieve existing
resource "digitalocean_reserved_ip" "load_balancer_ip" {
  region = digitalocean_kubernetes_cluster.my_cluster.region

  # Use count to ensure the floating IP is only allocated if it doesn't exist
  # count = length(data.digitalocean_floating_ip.load_balancer_ip_existing) > 0 ? 0 : 1
}

# module "traefik" {
#   source  = "sculley/traefik/kubernetes"
#   version = "1.0.2"

# }

# Create traefik namespace
resource "kubernetes_namespace" "traefik_namespace" {
  metadata {
    name = "traefik"
  }
}

resource "helm_release" "traefik" {
  name       = "traefik2"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  namespace  = "traefik"
  values = [
    file("${path.module}/values.yaml")
  ]
}

# Traefik service definition...
resource "kubernetes_service" "traefik" {
  metadata {
    name = "traefik"
    annotations  = {
      
    }
  }

  spec {
    # load_balancer_ip = digitalocean_reserved_ip.load_balancer_ip.ip_address # Use the allocated or existing floating IP

    selector = {
      "app.kubernetes.io/name" = "traefik"
    }

    port {
      name = "web"
      port = 80
      # target_port = 80
    }

    port {
      name = "traefik"
      port = 9000
      # target_port = 9000
    }

    type = "LoadBalancer"
  }
}

resource "digitalocean_reserved_ip_assignment" "load_balancer_ip" {
  ip_address = digitalocean_reserved_ip.load_balancer_ip.ip_address
  droplet_id = digitalocean_kubernetes_cluster.my_cluster.node_pool[0].nodes[0].droplet_id
}

# Define feedback-service deployment...
resource "kubernetes_deployment" "feedback_service" {
  metadata {
    name = "feedback-service"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "feedback-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "feedback-service"
        }
      }

      spec {
        container {
          name  = "feedback-service"
          image = "rightpurchase/feedback-service:1.0.1"
          port {
            # host_port      = 80
            container_port = 80
            name           = "web"
          }
        }
      }
    }
  }
}
