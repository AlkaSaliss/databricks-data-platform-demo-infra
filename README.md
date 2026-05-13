# Databricks Data Platform Demo Infra

This repository contains Terraform modules and Terragrunt live stacks for deploying a Databricks data platform foundation on AWS.

## Stack Overview

The live deployment is split into five stacks under `src/live/<env>/<region>`:

1. `terraform-state-infra`
2. `account-admin`
3. `network-infra`
4. `uc-metastore-infra`
5. `workspace-infra`

Recommended deployment order is the same as the list above. Destroy order is the reverse.

## Repository Layout

```text
.
├── Makefile
├── bin/
│   ├── set_aws_credentials.sh
│   └── set_env_vars.sh
├── doc/
│   ├── account-admin.md
│   ├── network-infra.md
│   ├── terraform-state-infra.md
│   ├── uc-metastore-infra.md
│   └── workspace-infra.md
└── src/
    ├── live/
    │   └── dev/
    │       ├── env.hcl
    │       └── eu-west-1/
    │           ├── account-admin/
    │           ├── network-infra/
    │           ├── terraform-state-infra/
    │           ├── uc-metastore-infra/
    │           ├── workspace-infra/
    │           └── region.hcl
    ├── modules/
    └── root.hcl
```

## Environment Variables

Before deploying, set the following environment variables in the current shell session:

- `AWS_PROFILE_NAME`
- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`
- `DATABRICKS_OWNER_EMAIL`
- `TF_STATE_BUCKET`
- `TF_STATE_DYNAMODB_TABLE`

You can source the local helper script if you use it:

```bash
. ./bin/set_env_vars.sh
```

`terraform-state-infra` requires `TF_STATE_BUCKET` and `TF_STATE_DYNAMODB_TABLE`.
The Databricks stacks require `DATABRICKS_ACCOUNT_ID`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET`, and `DATABRICKS_OWNER_EMAIL`.

## Stack Inputs

Most shared settings are centralized in:

- `src/live/dev/env.hcl`
- `src/live/dev/eu-west-1/region.hcl`
- `src/root.hcl`

Per-stack values stay in each stack's `terraform.tfvars`.

## Makefile Usage

The `Makefile` is intentionally simple and centers on stack operations.

```bash
# Show help
make help

# Plan one stack
make plan STACK=network-infra

# Deploy one stack
make deploy STACK=workspace-infra

# Destroy one stack
make destroy STACK=workspace-infra

# Run the full deployment sequence for one environment/region
make deploy-all ENV=dev REGION=eu-west-1

# Run the active CI/CD deployment sequence, excluding terraform-state-infra
make deploy-active-all ENV=dev REGION=eu-west-1
```

## GitHub Actions CI/CD

The repository uses two GitHub Actions workflows:

- `.github/workflows/pr-infra.yml` runs validation and planning on pull requests.
- `.github/workflows/deploy-infra.yml` runs manual deployment for an approved commit.

Both workflows target the active stacks sequentially for `dev/eu-west-1`:

1. `account-admin`
2. `network-infra`
3. `uc-metastore-infra`
4. `workspace-infra`

`terraform-state-infra` is intentionally excluded from CI/CD because it bootstraps the remote state bucket and lock table and is deployed once manually.

### GitHub Variables And Secrets

Both workflows read configuration from the `dev` GitHub Environment.
Configure required reviewers on that environment if PR planning and manual applies should wait for approval.
The workflow uses AWS credentials configured in GitHub secrets.

Configure these GitHub secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`

Optional secret:

- `AWS_SESSION_TOKEN`

Configure these GitHub variables:

- `DATABRICKS_OWNER_EMAIL`
- `DATABRICKS_ACCOUNT_ADMINS_JSON`
- `DATABRICKS_USERS_JSON`
- `WORKSPACE_USERS_JSON`
- `USER_DISPLAY_NAMES_JSON`

Optional variables:

- `UNITY_ADMIN_GROUP`
- `UNITY_USERS_GROUP`
- `CREATE_AUTOMATION_SERVICE_PRINCIPAL`
- `AUTOMATION_SERVICE_PRINCIPAL_NAME`

JSON variables must be valid JSON values because the workflow writes `terraform.tfvars.json`. Compact single-line JSON is recommended for GitHub variables, for example:

```json
["admin@example.com"]
```

```json
{
  "user@example.com": "User Name"
}
```

`TF_STATE_BUCKET` and `TF_STATE_DYNAMODB_TABLE` are not required by the workflow because the state bootstrap stack is excluded.
Network, metastore, and workspace names are defined directly in the tracked Terragrunt stack definitions under `src/live/dev/eu-west-1`.
The workflows generate runtime `terraform.tfvars.json` files with `scripts/generate-ci-tfvars.sh`.

### Pull Request Checks

The PR workflow runs:

- `make fmt-check`
- `make hcl-validate-active-all ENV=dev REGION=eu-west-1`
- `make validate-active-all ENV=dev REGION=eu-west-1`
- `make plan-active-all ENV=dev REGION=eu-west-1`

Plan logs are uploaded as GitHub Actions artifacts.

### Manual Deployment

From GitHub, open **Actions** > **Deploy Infrastructure** > **Run workflow**.

Use `action=plan` to run validation and planning only.
Use `action=apply` to run validation and planning first, then wait for the `dev` Environment approval before applying the active stacks sequentially.

## Stack Documentation

- [account-admin](./doc/account-admin.md)
- [terraform-state-infra](./doc/terraform-state-infra.md)
- [network-infra](./doc/network-infra.md)
- [uc-metastore-infra](./doc/uc-metastore-infra.md)
- [workspace-infra](./doc/workspace-infra.md)
