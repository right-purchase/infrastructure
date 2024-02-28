# Define DigitalOcean provider
provider "digitalocean" {
  token = var.DO_TOKEN
}

# Define Kubernetes provider
provider "kubernetes" {
  host                   = data.digitalocean_kubernetes_cluster.my_cluster.endpoint
  token                  = data.digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(data.digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)
}

data "digitalocean_kubernetes_cluster" "my_cluster" {
  name = var.cluster_name
}

# Define feedback-service deployment...
resource "kubernetes_deployment" "app_service" {
  metadata {
    name = var.service_name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.service_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.service_name
        }
      }

      spec {
        container {
          name  = var.service_name
          image = var.service_image

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

resource "kubernetes_service" "app_service" {
  metadata {
    name = kubernetes_deployment.app_service.metadata.0.name
  }

  spec {
    selector = {
      app = kubernetes_deployment.app_service.metadata.0.name
    }

    port {
      port = 80
    }

    type = "NodePort"
  }
}

resource "kubernetes_manifest" "app_service_ingress_route" {

  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "IngressRoute" #See https://doc.traefik.io/traefik/v2.3/routing/providers/kubernetes-crd/#kind-ingressroute
    metadata = {
      name      = kubernetes_deployment.app_service.metadata.0.name
      namespace = "default"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [{
        match = "Host(`${var.domain_name}`) && PathPrefix(`/feedback`)"
        kind  = "Rule"
        services = [{
          name = kubernetes_deployment.app_service.metadata.0.name
          port = 80
        }]
        middlewares = [{
          name = "${kubernetes_deployment.app_service.metadata.0.name}-middleware"
        }]
      }]
      tls = {
        store = {
          name = "default"
        }
        domains = [{
          main = var.domain_name,
          sans = ["www.${var.domain_name}"]
        }]
      }
    }
  }
}

resource "kubernetes_manifest" "app_service_middleware" {

  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${kubernetes_deployment.app_service.metadata.0.name}-middleware"
      namespace = "default"
    }
    spec = {
      stripPrefix = {
        prefixes = ["/feedback"]
      }
    }
  }
}
