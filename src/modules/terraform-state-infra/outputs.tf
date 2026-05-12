# Outputs for Terraform State Management Module

output "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.bucket_domain_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "state_backend_config" {
  description = "Backend configuration for Terraform state"
  value = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.region
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    encrypt        = var.enable_encryption
  }
}
