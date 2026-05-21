#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment="${ENV:-dev}"
region="${REGION:-eu-west-1}"

host="$(ENV="$environment" REGION="$region" "$repo_root/bin/resolve_databricks_host.sh")"

terraform_path="${DATABRICKS_TF_EXEC_PATH:-$(command -v terraform || true)}"
if [ -z "$terraform_path" ]; then
  echo "terraform was not found in PATH. Install Terraform or set DATABRICKS_TF_EXEC_PATH." >&2
  exit 1
fi

terraform_version="${DATABRICKS_TF_VERSION:-$("$terraform_path" version -json | python3 -c 'import json, sys; print(json.load(sys.stdin)["terraform_version"])')}"

cd "$repo_root/databricks/energy_market"
exec env \
  DATABRICKS_HOST="$host" \
  DATABRICKS_TF_EXEC_PATH="$terraform_path" \
  DATABRICKS_TF_VERSION="$terraform_version" \
  databricks bundle "$@"
