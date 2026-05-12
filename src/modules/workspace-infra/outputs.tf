# Outputs for the Databricks workspace infrastructure module

output "root_bucket" {
  value       = aws_s3_bucket.root_storage_bucket.bucket
  description = "Root storage bucket name"
}

output "cross_account_role_arn" {
  value       = aws_iam_role.cross_account_role.arn
  description = "AWS Cross account role ARN"
}

# Databricks Workspace Outputs
output "databricks_workspace_id" {
  value       = databricks_mws_workspaces.this.workspace_id
  description = "Databricks workspace ID"
}

output "databricks_workspace_url" {
  value       = databricks_mws_workspaces.this.workspace_url
  description = "Databricks workspace URL"
}

output "databricks_host" {
  value       = databricks_mws_workspaces.this.workspace_url
  description = "Databricks workspace host URL"
}
