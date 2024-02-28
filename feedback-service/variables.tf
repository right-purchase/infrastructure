variable "DO_TOKEN" {
  description = "DigitalOcean API token with read and write access"
  type        = string
  sensitive   = true
}

variable "FORM_URL" {
  description = "The URL of the form service"
  type        = string
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster created"
  type        = string
  default     = "right-purchase-cluster"
}

variable "domain_name" {
  description = "The domain name for the API Gateway service"
  type        = string
  default     = "testedafarinha.website"
}

variable "service_name" {
  description = "Name of the service to be deployed"
  type        = string
  default     = "feedback-service"
}

variable "service_image" {
  description = "Image of the service to be deployed"
  type        = string
  default     = "rightpurchase/feedback-service:1.0.1"
  
}