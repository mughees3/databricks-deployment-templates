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

# Convenience list other files use in `depends_on` so no workspace-scoped
# resource runs before the SP can actually authenticate + act as admin.
# (Both the SP admin grant AND the metastore assignment must be in place.)
locals {
  workspace_ready = [
    databricks_mws_permission_assignment.provisioner_admin,
    databricks_metastore_assignment.this,
  ]
}
