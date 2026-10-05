# Exercise only (with localstack_override.tf): where LocalStack, which plays
# production here, is listening. Delete both files to use real AWS.
variable "localstack_url" {
  type    = string
  default = "http://localhost:4566"
}
