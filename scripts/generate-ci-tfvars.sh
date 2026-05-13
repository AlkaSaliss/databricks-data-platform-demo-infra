#!/usr/bin/env bash
set -euo pipefail

require() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "::error::$name must be configured as a GitHub variable or secret" >&2
    exit 1
  fi
}

normalize_json() {
  local name="$1"
  local value="$2"
  local normalized
  local without_extra_brace

  if normalized="$(printf '%s' "$value" | tr -d '\r' | jq -c . 2>/dev/null)"; then
    printf '%s' "$normalized"
    return 0
  fi

  # Recover from a common GitHub variable copy/paste issue where a JSON object
  # gets one extra closing brace appended.
  without_extra_brace="$(printf '%s' "$value" | tr -d '\r')"
  without_extra_brace="${without_extra_brace%\}}"

  if normalized="$(printf '%s' "$without_extra_brace" | jq -c . 2>/dev/null)"; then
    echo "::warning::$name had an extra trailing closing brace; normalized it before writing tfvars" >&2
    printf '%s' "$normalized"
    return 0
  fi

  echo "::error::$name must be valid JSON. Use compact JSON such as [\"user@example.com\"] or {\"user@example.com\":\"User Name\"}." >&2
  exit 1
}

ENVIRONMENT="${1:-dev}"
REGION="${2:-eu-west-1}"

require DATABRICKS_ACCOUNT_ID
require DATABRICKS_CLIENT_ID
require DATABRICKS_CLIENT_SECRET
require DATABRICKS_OWNER_EMAIL
require DATABRICKS_ACCOUNT_ADMINS_JSON

command -v jq >/dev/null || {
  echo "::error::jq is required to generate Terraform JSON tfvars" >&2
  exit 1
}

live_dir="src/live/${ENVIRONMENT}/${REGION}"
test -d "$live_dir" || {
  echo "::error::Live directory not found: $live_dir" >&2
  exit 1
}

databricks_users_json="${DATABRICKS_USERS_JSON:-[]}"
workspace_users_json="${WORKSPACE_USERS_JSON:-[]}"
user_display_names_json="${USER_DISPLAY_NAMES_JSON:-{}}"
unity_admin_group="${UNITY_ADMIN_GROUP:-Unity Catalog Admins}"
unity_users_group="${UNITY_USERS_GROUP:-Unity Catalog Users}"
create_automation_service_principal="${CREATE_AUTOMATION_SERVICE_PRINCIPAL:-false}"
automation_service_principal_name="${AUTOMATION_SERVICE_PRINCIPAL_NAME:-terraform-automation-sp}"

databricks_account_admins_json="$(normalize_json DATABRICKS_ACCOUNT_ADMINS_JSON "$DATABRICKS_ACCOUNT_ADMINS_JSON")"
databricks_users_json="$(normalize_json DATABRICKS_USERS_JSON "$databricks_users_json")"
workspace_users_json="$(normalize_json WORKSPACE_USERS_JSON "$workspace_users_json")"
user_display_names_json="$(normalize_json USER_DISPLAY_NAMES_JSON "$user_display_names_json")"
create_automation_service_principal="$(normalize_json CREATE_AUTOMATION_SERVICE_PRINCIPAL "$create_automation_service_principal")"

rm -f \
  "$live_dir/account-admin/terraform.tfvars" \
  "$live_dir/workspace-infra/terraform.tfvars"

jq -n \
  --argjson databricks_account_admins "$databricks_account_admins_json" \
  --argjson databricks_users "$databricks_users_json" \
  --argjson user_display_names "$user_display_names_json" \
  --arg unity_admin_group "$unity_admin_group" \
  --arg unity_users_group "$unity_users_group" \
  --argjson create_automation_service_principal "$create_automation_service_principal" \
  --arg automation_service_principal_name "$automation_service_principal_name" \
  '{
    databricks_account_admins: $databricks_account_admins,
    databricks_users: $databricks_users,
    user_display_names: $user_display_names,
    unity_admin_group: $unity_admin_group,
    unity_users_group: $unity_users_group,
    create_automation_service_principal: $create_automation_service_principal,
    automation_service_principal_name: $automation_service_principal_name
  }' > "$live_dir/account-admin/terraform.tfvars.json"

jq -n \
  --argjson ws_users "$workspace_users_json" \
  '{
    ws_users: $ws_users
  }' > "$live_dir/workspace-infra/terraform.tfvars.json"
