###############################################################################
# backend.tf
# -----------------------------------------------------------------------------
# WHERE Terraform stores its state file. State is the record of what Terraform
# created; protecting it matters.
#
# DEFAULT (this file as shipped): LOCAL state — the file terraform.tfstate is
# written next to your code. Great for a first try on one laptop. NOT safe for
# teams or CI (no locking, easy to lose, may contain secrets).
#
# RECOMMENDED for real/shared use: a REMOTE S3 backend with DynamoDB locking.
# Steps:
#   1. Create the S3 bucket + DynamoDB table ONCE using ./bootstrap (see its
#      README). That gives you the bucket/table names.
#   2. Uncomment the block below and fill in those names.
#   3. Run `terraform init -migrate-state` to move local state to S3.
#
# The backend block cannot use variables (it's read before variables load),
# so the values are hard-coded here on purpose.
###############################################################################

# terraform {
#   backend "s3" {
#     bucket         = "REPLACE-with-your-tfstate-bucket"
#     key            = "databricks/aws/terraform.tfstate"
#     region         = "us-west-2"
#     dynamodb_table = "REPLACE-with-your-lock-table"
#     encrypt        = true
#   }
# }
