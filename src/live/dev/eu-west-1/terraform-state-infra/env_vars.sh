#!/bin/bash

export TF_STATE_BUCKET="dbx-terraform-state-dev-eu-west-1"
export TF_STATE_DYNAMODB_TABLE="dbx-terraform-locks-dev"

echo "Terraform backend environment variables set. Source this file before running Terragrunt commands: source env_vars.sh"