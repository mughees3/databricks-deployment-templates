###############################################################################
# workspace_resources.tf
# -----------------------------------------------------------------------------
# Optional "starter" objects created INSIDE the workspace so customers have
# something usable on day one. All are toggle-able via variables. They use the
# default (workspace-scoped) Databricks provider.
###############################################################################

# --- A small SQL warehouse for immediate querying -------------------------
resource "databricks_sql_endpoint" "starter" {
  count = var.create_sql_warehouse ? 1 : 0

  name             = "${local.name}-starter-wh"
  cluster_size     = "2X-Small" # smallest; cheap for a demo/starter.
  auto_stop_mins   = 10         # idle-stop to control cost.
  max_num_clusters = 1

  # Prefer serverless when the workspace supports it; falls back gracefully.
  enable_serverless_compute = true

  tags {
    custom_tags {
      key   = "ManagedBy"
      value = "terraform"
    }
  }

  depends_on = [databricks_metastore_assignment.this]
}

# --- Grant workspace admin to named users ---------------------------------
# Look up each email at the account level, then grant workspace admin.
data "databricks_user" "admins" {
  for_each  = toset(var.workspace_admins)
  provider  = databricks.mws
  user_name = each.value
}

resource "databricks_mws_permission_assignment" "admins" {
  for_each     = data.databricks_user.admins
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = each.value.id
  permissions  = ["ADMIN"]
}
