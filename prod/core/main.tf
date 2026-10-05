# The scan service's AWS resources in production, other than the database
# (see ../database). Imported into Terraform in August; applied from a laptop.

resource "aws_sqs_queue" "scans" {
  name                       = "scans-${var.environment}"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = false

  tags = local.tags
}

# Members download a CSV of their subscriptions from a link we email them.
resource "aws_s3_bucket" "exports" {
  bucket = "scan-member-exports-${var.environment}"

  tags = local.tags
}

resource "aws_s3_bucket_ownership_controls" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "exports" {
  depends_on = [aws_s3_bucket_ownership_controls.exports, aws_s3_bucket_public_access_block.exports]

  bucket = aws_s3_bucket.exports.id
  acl    = "public-read"
}

# The worker's role. The web role is managed by the Beanstalk environment, outside Terraform.
resource "aws_iam_role" "worker" {
  name = "scan-worker-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "worker" {
  name = "scan-worker"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "worker" {
  name = "/scan/${var.environment}/worker"

  tags = local.tags
}

# DATABASE_URL and SECRET_KEY for web and worker. The value is set by hand, not in Terraform.
resource "aws_secretsmanager_secret" "app" {
  name = "scan/${var.environment}/app"

  tags = local.tags
}
