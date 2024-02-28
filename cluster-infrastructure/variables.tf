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

variable "CERT_PATH" {
  description = "Path to the SSL/TLS certificate file"
  type        = string
  default     = "certificates/fullchain.pem"
}

variable "KEY_PATH" {
  description = "Path to the SSL/TLS key file"
  type        = string
  default     = "certificates/privkey.pem"

}
