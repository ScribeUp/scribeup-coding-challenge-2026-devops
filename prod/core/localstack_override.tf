# Exercise only: points the AWS provider at LocalStack, which plays production
# here. Terraform merges *_override.tf files into the configuration; delete this
# file (and localstack.tf) and the provider talks to real AWS.

provider "aws" {
  region                      = var.region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    iam            = var.localstack_url
    kms            = var.localstack_url
    logs           = var.localstack_url
    s3             = var.localstack_url
    secretsmanager = var.localstack_url
    sqs            = var.localstack_url
    ssm            = var.localstack_url
    sts            = var.localstack_url
  }
}
