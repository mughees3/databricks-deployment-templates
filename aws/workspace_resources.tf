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

  # Serverless requires the feature to be enabled for the account/region.
  # Default is false (classic PRO) so the apply works everywhere; flip the
  # sql_warehouse_serverless var to true where serverless is available.
  enable_serverless_compute = var.sql_warehouse_serverless
  warehouse_type            = "PRO" # PRO supports both classic and serverless.

  tags {
    custom_tags {
      key   = "ManagedBy"
      value = "terraform"
    }
  }

  # Needs the SP to be workspace admin and the metastore assigned first.
  depends_on = [local.workspace_ready]
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
  principal_id = tonumber(each.value.id) # principal_id is numeric; the data source returns it as a string.
  permissions  = ["ADMIN"]
}
