# uc-metastore-infra

This stack creates the Unity Catalog metastore resources shared by workspaces.

## Live Stack

- Path: `src/live/dev/eu-west-1/uc-metastore-infra`
- Terraform module: `src/modules/uc-metastore-infra`

## What It Creates

- Metastore S3 bucket
- IAM role and policies for Unity Catalog data access
- Databricks metastore
- Default metastore data access credential for the metastore root storage

The metastore owner is the Terraform Databricks service principal identified by `DATABRICKS_CLIENT_ID`. That principal later creates workspace-level Unity Catalog objects in `workspace-infra`, so it must have metastore-owner privileges such as `CREATE CATALOG`, `CREATE STORAGE CREDENTIAL`, and `CREATE EXTERNAL LOCATION`.

The metastore root storage credential is required by Unity Catalog workloads, including Lakeflow Declarative Pipelines, when they initialize managed storage. Without it, pipeline clusters can fail with `DAC_DOES_NOT_EXIST`.

## Required Environment Variables

- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`
- `DATABRICKS_OWNER_EMAIL`

## Main tfvars Inputs

Configure these in `src/live/dev/eu-west-1/uc-metastore-infra/terraform.tfvars`:

- `prefix`
- `metastore_name`

## Commands

```bash
make plan STACK=uc-metastore-infra
make deploy STACK=uc-metastore-infra
make destroy STACK=uc-metastore-infra
```
