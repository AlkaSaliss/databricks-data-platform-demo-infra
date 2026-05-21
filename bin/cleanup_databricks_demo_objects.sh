#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment="${ENV:-dev}"
region="${REGION:-eu-west-1}"
target="${DATABRICKS_BUNDLE_TARGET:-dev}"
catalog="${DATABRICKS_DEMO_CATALOG:-energy_market_demo}"
pipeline_name="${target}-energy-market-demo"

if ! host="$(ENV="$environment" REGION="$region" "$repo_root/bin/resolve_databricks_host.sh" 2>/dev/null)"; then
  echo "Skipping Databricks demo cleanup: no workspace host could be resolved." >&2
  exit 0
fi

export DATABRICKS_HOST="$host"

delete_pipeline() {
  local pipeline_id
  pipeline_id="$(
    databricks pipelines list-pipelines -o json 2>/dev/null |
      python3 -c '
import json
import sys

target_name = sys.argv[1]
try:
    payload = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(0)

for pipeline in payload.get("statuses", []) + payload.get("pipelines", []):
    if pipeline.get("name") == target_name:
        print(pipeline.get("pipeline_id") or pipeline.get("pipeline_id", ""))
        break
      ' "$pipeline_name"
  )"

  if [ -n "$pipeline_id" ]; then
    echo "Deleting Databricks pipeline $pipeline_name ($pipeline_id)"
    databricks pipelines delete "$pipeline_id" >/dev/null 2>&1 || true
  fi
}

delete_table() {
  local full_name="$1"
  echo "Deleting Databricks table if present: $full_name"
  databricks tables delete "$full_name" >/dev/null 2>&1 || true
}

delete_schema_tables() {
  local schema="$1"
  databricks tables list "$catalog" "$schema" -o json 2>/dev/null |
    python3 -c '
import json
import sys

catalog = sys.argv[1]
schema = sys.argv[2]
try:
    payload = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(0)

for table in payload.get("tables", []):
    print(table.get("full_name") or f"{catalog}.{schema}.{table.get('name')}")
    ' "$catalog" "$schema" |
    while IFS= read -r full_name; do
      [ -n "$full_name" ] && delete_table "$full_name"
    done
}

delete_pipeline

delete_table "$catalog.bronze.raw_fr_energy_grid"
delete_table "$catalog.silver.fr_energy_market_snapshots_15min"
delete_table "$catalog.gold.fr_energy_market_kpis_daily"

delete_schema_tables bronze
delete_schema_tables silver
delete_schema_tables gold
