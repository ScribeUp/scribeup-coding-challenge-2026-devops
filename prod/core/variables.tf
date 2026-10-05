variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "production"
}

locals {
  tags = {
    service = "scan"
    env     = var.environment
  }
}
