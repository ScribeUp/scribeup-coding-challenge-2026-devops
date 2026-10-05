# The scan service's AWS resources in production, other than the database
# (see ../database). Imported into Terraform in August; applied from a laptop.

data "aws_caller_identity" "current" {}

# Customer managed key for scan data at rest (CKV_AWS_27, CKV2_AWS_64).
resource "aws_kms_key" "data" {
  description             = "Scan service data at rest"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "WorkerDecrypt"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.worker.arn }
        Action    = ["kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
      },
    ]
  })

  tags = local.tags
}

resource "aws_kms_alias" "data" {
  name          = "alias/scan-${local.env}-data"
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_sqs_queue" "scans" {
  name                              = "scans-${local.env}"
  visibility_timeout_seconds        = 300
  message_retention_seconds         = 345600
  kms_master_key_id                 = aws_kms_key.data.arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.scans_dlq.arn
    maxReceiveCount     = 5
  })

  tags = local.tags
}

resource "aws_sqs_queue" "scans_dlq" {
  name                      = "scans-${local.env}-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.data.arn

  tags = local.tags
}

# Members download a CSV of their subscriptions from a link we email them.
resource "aws_s3_bucket" "exports" {
  bucket        = "scan-member-exports-${local.env}"
  force_destroy = true

  tags = local.tags
}

resource "aws_s3_bucket_ownership_controls" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# The worker's role. The web role is managed by the Beanstalk environment, outside Terraform.
resource "aws_iam_role" "worker" {
  name = "scan-worker-${local.env}"

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

# Least privilege (CKV_AWS_290, CKV_AWS_355).
resource "aws_iam_role_policy" "worker" {
  name = "scan-worker"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ScanQueue"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.scans.arn
      },
      {
        Sid      = "AppSecret"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.app.arn
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.worker.arn}:*"
      },
    ]
  })
}

# Retention set (CKV_AWS_158 / CKV_AWS_338); 7 days keeps CloudWatch costs down.
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/scan/${local.env}/worker"
  retention_in_days = 7

  tags = local.tags
}

# DATABASE_URL and SECRET_KEY for web and worker. The value is set by hand, not in Terraform.
resource "aws_secretsmanager_secret" "app" {
  name       = "scan/${local.env}/app"
  kms_key_id = aws_kms_key.data.arn

  tags = local.tags
}
