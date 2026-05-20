# account-admin

This stack manages Databricks account-level identities and groups required before deploying metastore and workspace resources.

## Live Stack

- Path: `src/live/dev/eu-west-1/account-admin`
- Terraform module: `src/modules/account-admin`

## What It Creates

- Databricks account users
- Databricks account admins
- Unity Catalog admin group with the account admin role
- Terraform service principal membership in the Unity Catalog admin group
- Optional regular users group
- Optional automation service principal

The admin group is the platform owner group for the demo. It is granted account admin at the Databricks account level, is later assigned workspace admin in `workspace-infra`, and owns the Unity Catalog metastore in `uc-metastore-infra`. The Terraform service principal identified by `DATABRICKS_CLIENT_ID` is also added to this group and explicitly granted the account admin role so CI can manage account, workspace, and Unity Catalog resources.

## Required Environment Variables

- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`
- `DATABRICKS_OWNER_EMAIL`
- `UNITY_ADMIN_GROUP` (optional, defaults to `Unity Catalog Admins`)
- `UNITY_USERS_GROUP` (optional, defaults to `Unity Catalog Users`)

## Main tfvars Inputs

Configure these in `src/live/dev/eu-west-1/account-admin/terraform.tfvars`:

- `databricks_account_admins`
- `databricks_users`
- `unity_admin_group`
- `user_display_names`
- `create_automation_service_principal`
- `automation_service_principal_name`

## Commands

```bash
make plan STACK=account-admin
make deploy STACK=account-admin
make destroy STACK=account-admin
```
