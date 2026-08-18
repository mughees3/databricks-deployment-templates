###############################################################################
# iam.tf
# -----------------------------------------------------------------------------
# The cross-account IAM role Databricks assumes to manage compute in YOUR AWS
# account. Databricks generates both the trust policy and the permissions
# policy for us via data sources, so we never hand-write JSON.
#
# Flow:
#   1. databricks_aws_assume_role_policy -> trust policy (who can assume).
#   2. aws_iam_role                      -> the role itself.
#   3. databricks_aws_crossaccount_policy-> the permissions the role needs.
#   4. aws_iam_role_policy               -> attaches those permissions.
#   5. databricks_mws_credentials        -> registers the role ARN with the
#                                            Databricks account.
###############################################################################

# Trust policy: allows the Databricks control-plane account to assume the role,
# scoped by external_id = your Databricks account ID (confused-deputy guard).
data "databricks_aws_assume_role_policy" "this" {
  provider    = databricks.mws
  external_id = var.databricks_account_id
}

resource "aws_iam_role" "cross_account" {
  name               = "${local.name}-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = local.tags
}

# The exact permissions Databricks needs (EC2, etc.) for a customer-managed VPC.
data "databricks_aws_crossaccount_policy" "this" {
  provider    = databricks.mws
  policy_type = "customer"
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "${local.name}-crossaccount-policy"
  role   = aws_iam_role.cross_account.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

# Register the role with the Databricks account as a "credential configuration".
resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  role_arn         = aws_iam_role.cross_account.arn
  credentials_name = "${local.name}-creds"

  # IAM role propagation is eventually consistent; make sure the permissions
  # policy is attached before Databricks validates the role.
  depends_on = [aws_iam_role_policy.cross_account]
}
