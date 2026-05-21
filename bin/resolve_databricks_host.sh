#!/usr/bin/env bash
set -euo pipefail

environment="${ENV:-dev}"
region="${REGION:-eu-west-1}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -n "${DATABRICKS_HOST:-}" ]; then
  workspace_url="$DATABRICKS_HOST"
else
  workspace_stack="$repo_root/src/live/${environment}/${region}/workspace-infra"
  if [ ! -d "$workspace_stack" ]; then
    echo "Workspace stack not found: $workspace_stack" >&2
    exit 1
  fi

  raw_workspace_output="$(
    cd "$workspace_stack" &&
      terragrunt output -raw databricks_workspace_url 2>/dev/null || true
  )"

  workspace_url="$(
    printf '%s\n' "$raw_workspace_output" |
      awk '
        /^[[:space:]]*(https:\/\/)?[A-Za-z0-9.-]+(\.cloud\.databricks\.com|\.azuredatabricks\.net)/ {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "")
          print
          exit
        }
      '
  )"

  if [ -z "$workspace_url" ]; then
    raw_workspace_state="$(
      cd "$workspace_stack" &&
        terragrunt state show databricks_mws_workspaces.this 2>/dev/null || true
    )"

    workspace_url="$(
      printf '%s\n' "$raw_workspace_state" |
        awk -F'=' '
          /^[[:space:]]*workspace_url[[:space:]]*=/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            gsub(/^"|"$/, "", $2)
            print $2
            exit
          }
        '
    )"
  fi

  if [ -z "$workspace_url" ]; then
    echo "DATABRICKS_HOST is not set and workspace-infra has no databricks_workspace_url output yet." >&2
    exit 1
  fi
fi

case "$workspace_url" in
https://*) printf '%s\n' "$workspace_url" ;;
*) printf 'https://%s\n' "$workspace_url" ;;
esac
