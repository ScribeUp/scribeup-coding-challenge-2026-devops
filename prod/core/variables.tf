variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "production"
}

locals {
  # Datadog and the app call this environment "prod" (DD_ENV=prod), so name resources to match.
  env = var.environment == "production" ? "prod" : var.environment

  tags = {
    service = "scan"
    env     = local.env
  }
}
