output "scan_queue_url" {
  value = aws_sqs_queue.scans.url
}

output "exports_bucket" {
  value = aws_s3_bucket.exports.bucket
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}
