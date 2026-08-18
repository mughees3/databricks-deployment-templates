###############################################################################
# unity_catalog.tf
# -----------------------------------------------------------------------------
# Unity Catalog (UC) is Databricks' governance layer. This file:
#
#   1. Creates a dedicated S3 bucket for UC-managed data.
#   2. Creates an IAM role UC uses to access that bucket (with the special
#      self-referencing trust policy UC requires).
#   3. Creates (or reuses) a regional METASTORE and assigns it to the workspace.
#   4. Registers the IAM role as a STORAGE CREDENTIAL and points an EXTERNAL
#      LOCATION at the bucket.
#   5. Creates a starter CATALOG.
#
# IMPORTANT: A Databricks account allows only ONE metastore per region. If you
# already have one in this region, set create_metastore = false and pass
# existing_metastore_id — the template will assign that instead of failing.
###############################################################################

# ---------------------------------------------------------------------------
# 1. UC data bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "uc" {
  bucket        = "${local.name}-uc"
  force_destroy = true
  tags = merge(local.tags, {
    Name = "${local.name}-uc"
  })
}

resource "aws_s3_bucket_public_access_block" "uc" {
  bucket                  = aws_s3_bucket.uc.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uc" {
  bucket = aws_s3_bucket.uc.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# 2. IAM role for the UC storage credential
# ---------------------------------------------------------------------------
# UC's trust policy is unusual: the role must trust the Databricks UC master
# role AND ITSELF (self-assume). Because the self-reference needs the role's own
# ARN, we build it in two passes: create the role with a bootstrap trust policy,
# then update it with the final policy that includes its own ARN.

# The permissions policy (what UC can do in the bucket).
data "databricks_aws_unity_catalog_policy" "this" {
  provider       = databricks.mws
  aws_account_id = data.aws_caller_identity.current.account_id
  bucket_name    = aws_s3_bucket.uc.bucket
  role_name      = "${local.name}-uc-access"
}

# Who we are (needed for the policy above and for the trust relationship).
data "aws_caller_identity" "current" {}

# The trust (assume-role) policy referencing the role's own ARN.
data "databricks_aws_unity_catalog_assume_role_policy" "this" {
  provider       = databricks.mws
  aws_account_id = data.aws_caller_identity.current.account_id
  role_name      = "${local.name}-uc-access"
  external_id    = var.databricks_account_id
  # unity_catalog_iam_arn defaults to the correct Databricks UC master role for
  # the commercial cloud; override only for GovCloud.
}

resource "aws_iam_role" "uc" {
  name               = "${local.name}-uc-access"
  assume_role_policy = data.databricks_aws_unity_catalog_assume_role_policy.this.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "uc" {
  name   = "${local.name}-uc-policy"
  role   = aws_iam_role.uc.id
  policy = data.databricks_aws_unity_catalog_policy.this.json
}

# ---------------------------------------------------------------------------
# 3. Metastore (create new, or reuse existing) + assignment
# ---------------------------------------------------------------------------
resource "databricks_metastore" "this" {
  count    = var.create_metastore ? 1 : 0
  provider = databricks.mws

  name   = "${local.name}-metastore"
  region = var.aws_region
  # Root storage for the metastore. Managed tables without an explicit location
  # land here.
  storage_root  = "s3://${aws_s3_bucket.uc.bucket}/metastore"
  force_destroy = true
}

# Resolve the metastore ID whether we created it or the caller supplied one.
locals {
  metastore_id = var.create_metastore ? databricks_metastore.this[0].id : var.existing_metastore_id
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  metastore_id = local.metastore_id
}

# ---------------------------------------------------------------------------
# 4. Storage credential + external location (workspace-scoped provider)
# ---------------------------------------------------------------------------
# These live INSIDE the workspace, so they use the default (workspace) provider
# and must wait for the metastore assignment.
resource "databricks_storage_credential" "uc" {
  name = "${local.name}-uc-cred"
  aws_iam_role {
    role_arn = aws_iam_role.uc.arn
  }
  comment = "Storage credential for the UC data bucket."

  # Wait for the metastore assignment AND for the provisioning SP to be a
  # workspace admin — otherwise this call is unauthorized.
  depends_on = [local.workspace_ready]
}

resource "databricks_external_location" "uc" {
  name            = "${local.name}-uc-loc"
  url             = "s3://${aws_s3_bucket.uc.bucket}/data"
  credential_name = databricks_storage_credential.uc.name
  comment         = "External location for the starter catalog's data."

  depends_on = [local.workspace_ready]
}

# ---------------------------------------------------------------------------
# 5. Starter catalog
# ---------------------------------------------------------------------------
resource "databricks_catalog" "starter" {
  name         = var.catalog_name
  storage_root = databricks_external_location.uc.url
  comment      = "Starter catalog created by the template."

  # ISOLATED = this catalog is only visible/usable from workspaces it's bound
  # to. We bind it to this workspace below. Change to "OPEN" to share it across
  # all workspaces on the metastore.
  isolation_mode = "ISOLATED"

  properties = {
    purpose = "starter"
  }

  depends_on = [databricks_external_location.uc]
}

# Bind the isolated catalog to this workspace so users here can access it.
resource "databricks_workspace_binding" "starter" {
  securable_name = databricks_catalog.starter.name
  securable_type = "catalog"
  workspace_id   = databricks_mws_workspaces.this.workspace_id
  binding_type   = "BINDING_TYPE_READ_WRITE"
}
