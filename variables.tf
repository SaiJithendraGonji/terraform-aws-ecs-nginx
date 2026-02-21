variable "environment" {
  description = "the environment name"
}

variable "service" {
  description = "the service name"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
}

variable "enable_https" {
  description = "Enable HTTPS listener and ACM certificate on the ALB"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for ACM certificate, required when enable_https is true"
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_https || (var.enable_https && var.domain_name != "")
    error_message = "domain_name must be set when enable_https is true."
  }
}