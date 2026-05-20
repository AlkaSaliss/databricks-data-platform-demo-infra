output "catalog_name" {
  value       = databricks_catalog.energy_market.name
  description = "Unity Catalog catalog name for the energy market demo."
}

output "bronze_schema_name" {
  value       = databricks_schema.bronze.name
  description = "Bronze schema name."
}

output "silver_schema_name" {
  value       = databricks_schema.silver.name
  description = "Silver schema name."
}

output "gold_schema_name" {
  value       = databricks_schema.gold.name
  description = "Gold schema name."
}

output "storage_credential_name" {
  value       = databricks_storage_credential.streaming_lake.name
  description = "Unity Catalog storage credential name for the streaming lake bucket."
}

output "external_location_name" {
  value       = databricks_external_location.streaming_lake.name
  description = "Unity Catalog external location name for the streaming lake bucket."
}

output "volume_name" {
  value       = databricks_volume.streaming_lake.name
  description = "Unity Catalog external volume name."
}

output "volume_path" {
  value       = "/Volumes/${databricks_catalog.energy_market.name}/${databricks_schema.bronze.name}/${databricks_volume.streaming_lake.name}"
  description = "Databricks volume path exposing the streaming lake bucket."
}

output "raw_fr_energy_grid_volume_path" {
  value       = "/Volumes/${databricks_catalog.energy_market.name}/${databricks_schema.bronze.name}/${databricks_volume.streaming_lake.name}/${local.raw_fr_energy_grid_prefix}"
  description = "Databricks volume path for Flink raw France energy-grid bronze Parquet files."
}
