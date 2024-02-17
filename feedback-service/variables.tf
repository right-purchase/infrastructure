variable "DO_TOKEN" {
  description = "DigitalOcean API token with read and write access"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster created"
  type        = string
  default     = "right-purchase-cluster"
}

variable "FORM_URL" {
  description = "The URL of the form service"
  type        = string
}
