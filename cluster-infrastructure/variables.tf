variable "DO_TOKEN" {
  description = "DigitalOcean API token with read and write access"
  type        = string
  sensitive   = true
}

variable "DNS_NAME" {
  description = "The DNS name for Traefik Load balancer"
  type        = string
  default     = "testedafarinha.website"
}
