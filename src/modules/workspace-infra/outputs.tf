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

output "lakehouse_catalog_name" {
  value       = databricks_catalog.energy_market.name
  description = "Unity Catalog catalog name for the energy market demo."
}

output "lakehouse_bronze_schema_name" {
  value       = databricks_schema.bronze.name
  description = "Bronze schema name for the energy market demo."
}

output "lakehouse_silver_schema_name" {
  value       = databricks_schema.silver.name
  description = "Silver schema name for the energy market demo."
}

output "lakehouse_gold_schema_name" {
  value       = databricks_schema.gold.name
  description = "Gold schema name for the energy market demo."
}

output "streaming_lake_storage_credential_name" {
  value       = databricks_storage_credential.streaming_lake.name
  description = "Unity Catalog storage credential name for the streaming lake bucket."
}

output "streaming_lake_external_location_name" {
  value       = databricks_external_location.streaming_lake.name
  description = "Unity Catalog external location name for the streaming lake bucket."
}

output "streaming_lake_volume_name" {
  value       = databricks_volume.streaming_lake.name
  description = "Unity Catalog external volume name for the streaming lake bucket."
}

output "streaming_lake_volume_path" {
  value       = "/Volumes/${databricks_catalog.energy_market.name}/${databricks_schema.bronze.name}/${databricks_volume.streaming_lake.name}"
  description = "Databricks volume path exposing the streaming lake bucket."
}

output "raw_fr_energy_grid_volume_path" {
  value       = "/Volumes/${databricks_catalog.energy_market.name}/${databricks_schema.bronze.name}/${databricks_volume.streaming_lake.name}/bronze/raw_fr_energy_grid/"
  description = "Databricks volume path for Flink raw France energy-grid bronze Parquet files."
}
