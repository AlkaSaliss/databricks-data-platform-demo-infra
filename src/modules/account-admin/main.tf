# Databricks Account Admin Module

data "databricks_user" "owner" {
  user_name = var.account_owner_email
  provider  = databricks.mws
}

data "databricks_service_principal" "terraform_sp" {
  provider       = databricks.mws
  application_id = var.databricks_client_id
}

# Create users at account level (not workspace level)
# This includes both regular users and account admins
resource "databricks_user" "unity_users" {
  provider  = databricks.mws
  for_each  = toset(concat(var.databricks_users, var.databricks_account_admins))
  user_name = each.key
  force     = true

  # Add display name if provided
  display_name = lookup(var.user_display_names, each.key, null)
}

# Create admin group for Unity Catalog
resource "databricks_group" "admin_group" {
  provider     = databricks.mws
  display_name = var.unity_admin_group

  # Allow instance pool creation for admins
  allow_instance_pool_create = true

  # Allow cluster creation for admins
  allow_cluster_create = true
}

# Add account admins to the admin group
resource "databricks_group_member" "admin_group_member" {
  provider  = databricks.mws
  for_each  = toset(var.databricks_account_admins)
  group_id  = databricks_group.admin_group.id
  member_id = databricks_user.unity_users[each.value].id
}

resource "databricks_group_member" "add_account_owner_to_admin_group" {
  provider  = databricks.mws
  group_id  = databricks_group.admin_group.id
  member_id = data.databricks_user.owner.id
  # member_id = databricks_user.owner.id
}

resource "databricks_group_member" "terraform_sp_admin" {
  provider  = databricks.mws
  group_id  = databricks_group.admin_group.id
  member_id = data.databricks_service_principal.terraform_sp.id
}

# Assign account admin role to specified users
# This is a prerequisite for creating metastores
resource "databricks_user_role" "account_admin_role" {
  provider = databricks.mws
  for_each = toset(var.databricks_account_admins)
  user_id  = databricks_user.unity_users[each.value].id
  role     = "account_admin"
}

resource "databricks_group_role" "admin_group_account_admin" {
  provider = databricks.mws
  group_id = databricks_group.admin_group.id
  role     = "account_admin"
}

resource "databricks_service_principal_role" "terraform_sp_account_admin" {
  provider             = databricks.mws
  service_principal_id = data.databricks_service_principal.terraform_sp.id
  role                 = "account_admin"
}

# Optional: Create additional groups for regular users
resource "databricks_group" "users_group" {
  count        = length(var.databricks_users) > 0 ? 1 : 0
  provider     = databricks.mws
  display_name = var.unity_users_group
}

# Add regular users to the users group
resource "databricks_group_member" "users_group_member" {
  provider  = databricks.mws
  for_each  = length(var.databricks_users) > 0 ? toset(var.databricks_users) : []
  group_id  = databricks_group.users_group[0].id
  member_id = databricks_user.unity_users[each.value].id
}

# Service Principal for automation (optional)
resource "databricks_service_principal" "automation_sp" {
  count        = var.create_automation_service_principal ? 1 : 0
  provider     = databricks.mws
  display_name = var.automation_service_principal_name

  # Allow cluster creation for automation
  allow_cluster_create = true

  # Allow instance pool creation for automation
  allow_instance_pool_create = true
}

# Add service principal to admin group if created
resource "databricks_group_member" "automation_sp_admin" {
  count     = var.create_automation_service_principal ? 1 : 0
  provider  = databricks.mws
  group_id  = databricks_group.admin_group.id
  member_id = databricks_service_principal.automation_sp[0].id
}

# Assign account admin role to service principal
resource "databricks_service_principal_role" "automation_sp_admin_role" {
  count                = var.create_automation_service_principal ? 1 : 0
  provider             = databricks.mws
  service_principal_id = databricks_service_principal.automation_sp[0].id
  role                 = "account_admin"
}
