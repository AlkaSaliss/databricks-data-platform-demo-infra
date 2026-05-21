# workspace-infra

This stack creates the Databricks workspace, binds it to the previously created network and Unity Catalog metastore, and creates the demo lakehouse objects used by the Databricks bundle.

## Live Stack

- Path: `src/live/dev/eu-west-1/workspace-infra`
- Terraform module: `src/modules/workspace-infra`

## Dependencies

Deploy these first:

1. `terraform-state-infra`
2. `account-admin`
3. `network-infra`
4. `uc-metastore-infra`
5. `streaming-lake-infra`

## What It Creates

- Databricks cross-account IAM role
- Workspace root storage bucket
- Databricks MWS credentials, network, and storage configuration
- Databricks workspace
- Metastore assignment
- Workspace permission assignments for admins and users
- Workspace admin access for the Unity Catalog admin group created by `account-admin`
- Catalog `energy_market_demo`
- Schemas `bronze`, `silver`, and `gold`
- IAM role and read-only Unity Catalog storage credential for the streaming lake bucket
- External location and external volume `energy_market_demo.bronze.streaming_lake`

The catalog and demo schemas are configured with `force_destroy` so `make destroy-active-all` can remove Lakeflow-created tables and materialized views before deleting the schemas. This is intentionally scoped to Databricks-managed demo objects; the external streaming lake S3 bucket is protected separately by `streaming-lake-infra`.

## Required Environment Variables

- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`
- `DATABRICKS_OWNER_EMAIL`

## Main tfvars Inputs

Configure these in `src/live/dev/eu-west-1/workspace-infra/terraform.tfvars`:

- `prefix`
- `workspace_name`
- `lakehouse_prefix`
- `streaming_lake_bucket_name`
- `streaming_lake_bucket_arn`
- `ws_users`

## Commands

```bash
make plan STACK=workspace-infra
make deploy STACK=workspace-infra
make destroy STACK=workspace-infra
```

The external volume exposes the streaming lake bucket at:

```text
/Volumes/energy_market_demo/bronze/streaming_lake
```

The Databricks Asset Bundle reads Flink raw bronze files from:

```text
/Volumes/energy_market_demo/bronze/streaming_lake/bronze/raw_fr_energy_grid/
```
