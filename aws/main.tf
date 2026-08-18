###############################################################################
# main.tf
# -----------------------------------------------------------------------------
# Shared locals and the FINAL workspace resource. The individual building
# blocks live in dedicated files so each concern is easy to read:
#
#   network.tf         -> VPC, subnets, security group, VPC endpoints
#   iam.tf             -> cross-account IAM role Databricks assumes
#   storage.tf         -> workspace root S3 bucket + policy
#   unity_catalog.tf   -> metastore, storage credential, catalog
#   workspace_resources.tf -> starter SQL warehouse, admin grants
#
# Provisioning order is handled automatically by Terraform's dependency graph;
# you do not need to run anything in a special sequence.
###############################################################################

# Random suffix keeps global names (S3 buckets, IAM roles) unique per deploy.
resource "random_string" "suffix" {
  special = false
  upper   = false
  length  = 6
}

locals {
  # e.g. "dbx-a1b2c3" — used as the base name for everything.
  name = "${var.prefix}-${random_string.suffix.result}"

  # Merge caller tags with a marker so these resources are easy to find/clean.
  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Template  = "databricks-cloud-templates/aws"
  })
}

###############################################################################
# The Databricks E2 workspace — the keystone resource.
# It stitches together the three account-level configs created elsewhere:
#   * credentials (IAM role)          -> iam.tf
#   * storage configuration (S3)      -> storage.tf
#   * network (VPC/subnets/sg)        -> network.tf
###############################################################################
resource "databricks_mws_workspaces" "this" {
  provider       = databricks.mws
  account_id     = var.databricks_account_id
  aws_region     = var.aws_region
  workspace_name = local.name

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

  # Wait until the workspace is fully RUNNING before the workspace-scoped
  # provider tries to create catalogs/warehouses inside it.
  token {
    comment = "Terraform (${local.name})"
  }
}
