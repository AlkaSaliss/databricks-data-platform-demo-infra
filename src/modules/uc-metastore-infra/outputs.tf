output "metastore_bucket" {
  value       = aws_s3_bucket.metastore.bucket
  description = "Unity Catalog metastore bucket name"
}

output "unity_catalog_iam_role_arn" {
  value       = aws_iam_role.metastore_data_access.arn
  description = "Unity Catalog metastore data access IAM role ARN"
}

output "metastore_data_access_name" {
  value       = databricks_metastore_data_access.default.name
  description = "Default Unity Catalog metastore data access credential name"
}

output "metastore_id" {
  value       = databricks_metastore.this.id
  description = "Unity Catalog metastore ID"
}

output "metastore_name" {
  value       = databricks_metastore.this.name
  description = "Unity Catalog metastore name"
}
