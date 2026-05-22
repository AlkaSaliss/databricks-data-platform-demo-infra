#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment="${ENV:-dev}"
region="${REGION:-eu-west-1}"

host="$(ENV="$environment" REGION="$region" "$repo_root/bin/resolve_databricks_host.sh")"
target="dev"
previous_arg=""

for arg in "$@"; do
  if [ "$previous_arg" = "-t" ] || [ "$previous_arg" = "--target" ]; then
    target="$arg"
    previous_arg=""
    continue
  fi

  case "$arg" in
  -t | --target)
    previous_arg="$arg"
    ;;
  --target=*)
    target="${arg#--target=}"
    ;;
  esac
done

bundle_state_dir="$repo_root/databricks/energy_market/.databricks/bundle/$target"
terraform_state="$bundle_state_dir/terraform/terraform.tfstate"

if [ -f "$terraform_state" ]; then
  state_host="$(
    python3 - "$terraform_state" <<'PY'
import json
import sys
from urllib.parse import urlparse

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        state = json.load(handle)
except (OSError, json.JSONDecodeError):
    sys.exit(0)

for resource in state.get("resources", []):
    if resource.get("type") != "databricks_pipeline":
        continue
    for instance in resource.get("instances", []):
        url = instance.get("attributes", {}).get("url")
        if url:
            parsed = urlparse(url)
            if parsed.scheme and parsed.netloc:
                print(f"{parsed.scheme}://{parsed.netloc}")
                sys.exit(0)
PY
  )"

  if [ -n "$state_host" ] && [ "$state_host" != "$host" ]; then
    echo "Removing stale local Databricks bundle Terraform state for target '$target' ($state_host != $host)." >&2
    rm -rf "$bundle_state_dir/terraform"
  fi
fi

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
