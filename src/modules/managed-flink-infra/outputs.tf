output "application_name" {
  value       = aws_kinesisanalyticsv2_application.bronze.name
  description = "Amazon Managed Service for Apache Flink application name."
}

output "application_arn" {
  value       = aws_kinesisanalyticsv2_application.bronze.arn
  description = "Amazon Managed Service for Apache Flink application ARN."
}

output "artifact_bucket_name" {
  value       = aws_s3_bucket.artifacts.bucket
  description = "S3 bucket containing the Managed Flink application archive."
}

output "application_zip_s3_uri" {
  value       = "s3://${aws_s3_bucket.artifacts.bucket}/${aws_s3_object.application_zip.key}"
  description = "S3 URI of the Managed Flink application archive."
}

output "cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.flink.name
  description = "CloudWatch log group for Managed Flink application logs."
}

output "start_application" {
  value       = var.start_application
  description = "Whether Terraform starts the Managed Flink application after deployment."
}
