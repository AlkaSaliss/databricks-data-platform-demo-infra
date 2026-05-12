# network-infra

This stack creates the AWS network baseline used by the Databricks workspace.

## Live Stack

- Path: `src/live/dev/eu-west-1/network-infra`
- Terraform module: `src/modules/network-infra`

## What It Creates

- VPC
- Public and private subnets
- Default security group configuration
- VPC endpoints for S3, STS, and Kinesis Streams

## Required Environment Variables

AWS credentials must be available in the shell used to run Terragrunt.

## Main tfvars Inputs

Configure these in `src/live/dev/eu-west-1/network-infra/terraform.tfvars`:

- `prefix`
- `cidr_block`

## Commands

```bash
make plan STACK=network-infra
make deploy STACK=network-infra
make destroy STACK=network-infra
```
