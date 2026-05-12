# terraform-state-infra

This stack creates the S3 bucket and DynamoDB table used by Terragrunt remote state.

## Live Stack

- Path: `src/live/dev/eu-west-1/terraform-state-infra`
- Terraform module: `src/modules/terraform-state-infra`

## What It Creates

- Terraform state S3 bucket
- Terraform lock DynamoDB table
- Optional lifecycle, encryption, and versioning configuration

## Required Environment Variables

- `TF_STATE_BUCKET`
- `TF_STATE_DYNAMODB_TABLE`

AWS credentials must also be available in the shell used to run Terragrunt.

## Main tfvars Inputs

Configure these in `src/live/dev/eu-west-1/terraform-state-infra/terraform.tfvars`:

- `enable_versioning`
- `enable_encryption`
- `lifecycle_rules`
- `tags`

## Commands

```bash
make plan STACK=terraform-state-infra
make deploy STACK=terraform-state-infra
make destroy STACK=terraform-state-infra
```
