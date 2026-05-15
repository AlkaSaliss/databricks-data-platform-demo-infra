output "bronze_bucket_name" {
  value       = aws_s3_bucket.bronze.bucket
  description = "S3 bucket used for streaming bronze data."
}

output "bronze_bucket_arn" {
  value       = aws_s3_bucket.bronze.arn
  description = "ARN of the S3 bucket used for streaming bronze data."
}

output "raw_fr_energy_grid_bronze_uri" {
  value       = "s3://${aws_s3_bucket.bronze.bucket}/${local.raw_fr_prefix}"
  description = "Default S3 URI for raw France energy-grid bronze Parquet output."
}
