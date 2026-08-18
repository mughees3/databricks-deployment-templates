###############################################################################
# providers.tf
# -----------------------------------------------------------------------------
# Configures HOW Terraform talks to AWS and Databricks.
#
# Databricks on AWS is provisioned in two layers, so we declare the Databricks
# provider TWICE:
#
#   * databricks.mws  -> the ACCOUNT API (accounts.cloud.databricks.com).
#                        Used to create the workspace, networks, credentials,
#                        storage config, and the Unity Catalog metastore.
#
#   * databricks (default) -> the WORKSPACE API. Only usable AFTER the
#                        workspace exists. Used for in-workspace objects like
#                        catalogs, warehouses, users, and grants.
#
# Authentication:
#   * AWS  — resolved from your normal AWS credential chain (env vars, SSO,
#            shared profile). Set `aws_profile` in terraform.tfvars if you use
#            a named profile; leave it null to use the default chain.
#   * Databricks account — uses an account-level OAuth service principal
#            (client_id / client_secret). These are SECRETS: pass them via
#            environment variables TF_VAR_databricks_client_id /
#            TF_VAR_databricks_client_secret, never in a committed file.
###############################################################################

# --- AWS -------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  # Optional named profile. When null, the default AWS credential chain is used
  # (great for CI, where creds usually come from env vars or an assumed role).
  profile = var.aws_profile
}

# --- Databricks ACCOUNT provider (workspace + metastore provisioning) ------
provider "databricks" {
  alias = "mws"

  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id

  # OAuth service principal (M2M) credentials. Create one in the Databricks
  # account console: Settings -> Identity -> Service principals -> OAuth secret.
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

# --- Databricks WORKSPACE provider (in-workspace objects) ------------------
# Points at the workspace this template creates. Because the workspace URL is
# only known after apply, we read it from the workspace resource's output.
# Terraform builds the dependency graph automatically, so this provider is only
# used once the workspace exists.
provider "databricks" {
  # (default, no alias)

  host = databricks_mws_workspaces.this.workspace_url

  # Same service principal authenticates here. It becomes the workspace's first
  # admin automatically when it creates the workspace.
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
