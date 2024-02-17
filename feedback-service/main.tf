# Define DigitalOcean provider
provider "digitalocean" {
  token = var.DO_TOKEN
}

data "digitalocean_kubernetes_cluster" "my_cluster" {
  name = var.cluster_name
}

# Define Kubernetes provider
provider "kubernetes" {
  host                   = data.digitalocean_kubernetes_cluster.my_cluster.endpoint
  token                  = data.digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(data.digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)
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

          env {
            name  = "FORM_URL"
            value = var.FORM_URL
          }

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
      name      = "feedback-service-middleware"
      namespace = "default"
    }
    spec = {
      stripPrefix = {
        prefixes = ["/feedback"]
      }
    }
  }
}
