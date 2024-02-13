terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.34.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
  }
}

variable "DO_TOKEN" {
  description = "DigitalOcean API token with read and write access"
  type        = string
  sensitive   = true
}

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

# Allocate floating IP if it doesn't exist, or retrieve existing
resource "digitalocean_floating_ip" "load_balancer_ip" {
  region = digitalocean_kubernetes_cluster.my_cluster.region

  # Use count to ensure the floating IP is only allocated if it doesn't exist
  # count = length(data.digitalocean_floating_ip.load_balancer_ip_existing) > 0 ? 0 : 1
}

# Define permissions that Traefik needs from Kubernetes to work properly
resource "kubernetes_cluster_role" "traefik" {
  metadata {
    name = "traefik"
  }

  rule {
    api_groups = ["", "networking.k8s.io"]
    resources  = ["secrets", "services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingressclasses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }

}

resource "kubernetes_service_account" "traefik" {
  metadata {
    name      = "traefik-account"
    namespace = "default"
  }
}

resource "kubernetes_cluster_role_binding" "traefik" {
  metadata {
    name = "traefik-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.traefik.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.traefik.metadata[0].name
    namespace = kubernetes_service_account.traefik.metadata[0].namespace
  }
}

# # Bind the permissions to the Traefik service account
# resource "kubernetes_cluster_role_binding" "traefik" {
#   metadata {
#     name = "traefik"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io/v1"
#     kind      = "ClusterRole"
#     name      = kubernetes_cluster_role.traefik.metadata[0].name
#   }

#   subject {
#     kind      = "ServiceAccount"
#     name      = "default"
#     namespace = "default"
#   }
# }


# resource "kubernetes_manifest" "feedback_service" {

#   manifest = {
#     "apiVersion" = "networking.k8s.io/v1"
#     "kind"       = "Ingress"
#     "metadata" = {
#       "name"      = "feedback-service"
#       "namespace" = "kube-system"
#     }
#     "spec" = {
#       "rules" = [
#         {
#           "http" = {
#             "paths" = [
#               {
#                 "path"     = "/feedback"
#                 "pathType" = "Prefix"
#                 "backend" = {
#                   "service" = {
#                     "name" = "feedback-service"
#                     "port" = {
#                       "number" = 80
#                     }
#                   }
#                 }
#               }
#             ]
#           }
#         }
#       ]
#     }
#   }
# }

# # Retrieve existing floating IP
# data "digitalocean_floating_ip" "load_balancer_ip_existing" {
#   region = digitalocean_kubernetes_cluster.my_cluster.region

#   # Replace this with the desired floating IP address if known
#   # If not known, Terraform will attempt to find an existing floating IP in the region
#   # (You can also filter by other criteria using filters argument)
# }

# Traefik deployment definition...
resource "kubernetes_deployment" "traefik" {
  metadata {
    name = "traefik"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "traefik"
      }
    }

    template {

      metadata {
        labels = {
          app = "traefik"
        }
        # Traefik deployment annotations
        # annotations = {
        #   "traefik.http.routers.feedback-service.rule"                 = "PathPrefix(`/feedback`)"
        #   "traefik.http.routers.feedback-service.middlewares"          = "strip-prefix"
        #   "traefik.http.middlewares.strip-prefix.stripprefix.prefixes" = "/feedback"
        # }
      }

      spec {
        container {
          name  = "traefik"
          image = "traefik:v2.11"

          args = [
            "--api.insecure=true",
            "--providers.kubernetesingress",
            # "--providers.kubernetesingress.namespaces=[*]",
            # "--providers.kubernetesingress",
            # "--providers.kubernetesingress.namespaces=['default', 'kube-system']",
          ]

          port {
            name           = "web"
            container_port = 80
          }

          port {
            container_port = 8080
            name           = "dashboard"
          }
        }
      }
    }
  }
}

# Traefik service definition...
resource "kubernetes_service" "traefik" {
  metadata {
    name = "traefik"
  }

  spec {
    # load_balancer_ip = digitalocean_floating_ip.load_balancer_ip.*.ip[0] # Use the allocated or existing floating IP
    load_balancer_ip = digitalocean_floating_ip.load_balancer_ip.ip_address # Use the allocated or existing floating IP

    selector = {
      app = "traefik"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    port {
      name        = "maintenance"
      port        = 8080
      target_port = 8080
    }

    type = "LoadBalancer"
  }
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

resource "kubernetes_deployment" "whoami" {
  metadata {
    name = "whoami"
    labels = {
      app = "whoami"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "whoami"
      }
    }

    template {
      metadata {
        labels = {
          app = "whoami"
        }
      }

      spec {
        container {
          name  = "whoami"
          image = "traefik/whoami"

          port {
            name           = "web"
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "whoami" {
  metadata {
    name = "whoami"
  }

  spec {
    selector = {
      app = "whoami"
    }

    port {
      name        = "web"
      port        = 80
      target_port = "web"
    }
  }
}

# resource "kubernetes_ingress" "whoami" {
#   metadata {
#     name = "whoami-ingress"
#   }

#   spec {
#     rule {
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"

#           backend {
#             service {
#               name = kubernetes_service.whoami.metadata[0].name
#               port {
#                 name = "web"
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

resource "kubernetes_manifest" "whoami_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name = "whoami-ingress"
      namespace = "default"
    }
    spec = {
      rules = [
        {
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = kubernetes_service.whoami.metadata[0].name
                    port = {
                      name = "web"
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }
}

# # Attach floating IP to Load Balancer
# resource "digitalocean_kubernetes_service_lb_attachment" "load_balancer_ip_attachment" {
#   service_id  = kubernetes_service.traefik.id
#   floating_ip = digitalocean_floating_ip.load_balancer_ip.*.ip[0] # Use the allocated or existing floating IP
# }
