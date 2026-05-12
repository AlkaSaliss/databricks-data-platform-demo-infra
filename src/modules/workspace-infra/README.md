# workspace-infra Module

This module creates the Databricks workspace layer on top of an existing network and an existing Unity Catalog metastore.

## Expects Existing Dependencies

- VPC ID
- Private subnet IDs
- Security group IDs
- Unity Catalog metastore ID
- Databricks admin group ID

## Creates

- AWS cross-account IAM role
- Workspace root storage bucket
- Databricks MWS credentials
- Databricks network and storage configuration
- Databricks workspace
- Metastore assignment
- Workspace user and admin permission assignments

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
- `tags` (optional)

## Outputs

- `root_bucket`
- `cross_account_role_arn`
- `databricks_workspace_id`
- `databricks_workspace_url`
- `databricks_host`
