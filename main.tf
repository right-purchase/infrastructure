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

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  values = [
    file("${path.module}/values.yaml")
  ]
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
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "feedback_service" {
  metadata {
    name = "feedback-service"
  }

  spec {
    selector = {
      app = "feedback-service"
    }

    port {
      port = 80
    }

    type = "NodePort"
  }
}

resource "kubernetes_manifest" "feedback_service_ingress_route" {

  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "feedback-service"
      namespace = "default"
    }
    spec = {
      entryPoints = ["web"]
      routes = [{
        match = "PathPrefix(`/feedback`)"
        kind  = "Rule"
        services = [{
          name = "feedback-service"
          port = 80
        }]
        middlewares = [{
          name = "feedback-service-middleware"
        }]
      }]
    }
  }
}

resource "kubernetes_manifest" "feedback_service_middleware" {

  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name = "feedback-service-middleware"
      namespace = "default"
    }
    spec = {
      stripPrefix = {
        prefixes = ["/feedback"]
      }
    }
  }
}
