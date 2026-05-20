# workspace-infra Module

This module creates the Databricks workspace layer on top of an existing network and an existing Unity Catalog metastore. It also creates the demo Unity Catalog lakehouse objects used by the Databricks Asset Bundle.

## Expects Existing Dependencies

- VPC ID
- Private subnet IDs
- Security group IDs
- Unity Catalog metastore ID
- Databricks admin group ID
- Streaming lake S3 bucket name and ARN

## Creates

- AWS cross-account IAM role
- Workspace root storage bucket
- Databricks MWS credentials
- Databricks network and storage configuration
- Databricks workspace
- Metastore assignment
- Workspace user and admin permission assignments
- Catalog `energy_market_demo`
- Schemas `bronze`, `silver`, and `gold`
- Storage credential, external location, and external volume for the streaming lake bucket

## Inputs

- `prefix`
- `region`
- `vpc_id`
- `subnet_ids`
- `security_group_ids`
- `metastore_id`
- `admin_group_id`
- `databricks_account_id`
- `databricks_client_id`
- `databricks_client_secret`
- `workspace_name` (optional)
- `ws_users` (optional)
- `roles_to_assume` (optional)
- `lakehouse_prefix` (optional)
- `streaming_lake_bucket_name`
- `streaming_lake_bucket_arn`
- `lakehouse_catalog_name` (optional)
- `lakehouse_bronze_schema_name` (optional)
- `lakehouse_silver_schema_name` (optional)
- `lakehouse_gold_schema_name` (optional)
- `streaming_lake_volume_name` (optional)
- `tags` (optional)

## Outputs

- `root_bucket`
- `cross_account_role_arn`
- `databricks_workspace_id`
- `databricks_workspace_url`
- `databricks_host`
- `lakehouse_catalog_name`
- `streaming_lake_volume_path`
- `raw_fr_energy_grid_volume_path`
