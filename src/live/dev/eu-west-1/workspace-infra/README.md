# workspace-infra Live Stack

This directory contains the Terragrunt live stack for deploying the Databricks workspace and demo lakehouse objects in `dev / eu-west-1`.

## Dependencies

Deploy these stacks first:

1. `terraform-state-infra`
2. `account-admin`
3. `network-infra`
4. `uc-metastore-infra`
5. `streaming-lake-infra`

## Required Environment Variables

- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`
- `DATABRICKS_OWNER_EMAIL`

Source your local helper if you use it:

```bash
. ./bin/set_env_vars.sh
```

## Commands

```bash
make plan STACK=workspace-infra
make deploy STACK=workspace-infra
make destroy STACK=workspace-infra
```
