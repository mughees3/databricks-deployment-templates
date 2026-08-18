###############################################################################
# identity.tf
# -----------------------------------------------------------------------------
# CRITICAL for a working deploy: the account-level OAuth service principal that
# creates the workspace is NOT automatically an admin *inside* that workspace.
#
# The workspace-scoped Databricks provider (providers.tf) authenticates AS this
# service principal, so if it isn't a workspace admin, every in-workspace
# resource (storage credential, external location, catalog, SQL warehouse)
# fails with PERMISSION_DENIED.
#
# This file looks up the SP by its client/application ID and grants it ADMIN on
# the new workspace via the account API. Everything workspace-scoped then
# `depends_on` this assignment (see the locals below, referenced elsewhere).
###############################################################################

# Resolve the numeric account-level ID (sp_id) of the provisioning SP from the
# client_id we authenticate with. Uses the account provider.
data "databricks_service_principal" "provisioner" {
  provider       = databricks.mws
  application_id = var.databricks_client_id
}

# Make the provisioning SP an admin of the new workspace.
resource "databricks_mws_permission_assignment" "provisioner_admin" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = data.databricks_service_principal.provisioner.sp_id
  permissions  = ["ADMIN"]
}

# The admin grant is eventually consistent: for a few seconds after it's
# created, the workspace API may still reject the SP with "Authentication
# failed". Wait it out before creating any workspace-scoped object.
resource "time_sleep" "admin_propagation" {
  depends_on      = [databricks_mws_permission_assignment.provisioner_admin]
  create_duration = "30s"
}

# Convenience list other files use in `depends_on` so no workspace-scoped
# resource runs before the SP can actually authenticate + act as admin.
# (Both the SP admin grant + its propagation AND the metastore assignment.)
locals {
  workspace_ready = [
    time_sleep.admin_propagation,
    databricks_metastore_assignment.this,
  ]
}
