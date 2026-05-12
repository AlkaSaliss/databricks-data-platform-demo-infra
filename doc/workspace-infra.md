# workspace-infra

This stack creates the Databricks workspace and binds it to the previously created network and Unity Catalog metastore.

## Live Stack

- Path: `src/live/dev/eu-west-1/workspace-infra`
- Terraform module: `src/modules/workspace-infra`

## Dependencies

Deploy these first:

1. `terraform-state-infra`
2. `account-admin`
3. `network-infra`
4. `uc-metastore-infra`

## What It Creates

- Databricks cross-account IAM role
- Workspace root storage bucket
- Databricks MWS credentials, network, and storage configuration
- Databricks workspace
- Metastore assignment
- Workspace permission assignments for admins and users

## Required Environment Variables

- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`
- `DATABRICKS_OWNER_EMAIL`

## Main tfvars Inputs

Configure these in `src/live/dev/eu-west-1/workspace-infra/terraform.tfvars`:

- `prefix`
- `workspace_name`
- `ws_users`

## Commands

```bash
make plan STACK=workspace-infra
make deploy STACK=workspace-infra
make destroy STACK=workspace-infra
```
