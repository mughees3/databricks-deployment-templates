###############################################################################
# versions.tf
# -----------------------------------------------------------------------------
# Pins Terraform and provider versions. Pinning versions is what makes a
# deployment REPRODUCIBLE: the same code produces the same result next month.
# Update these deliberately, then run `terraform init -upgrade`.
###############################################################################

terraform {
  # Terraform CLI version. 1.5+ supports the `import` and `check` blocks.
  required_version = ">= 1.5.0"

  required_providers {
    # Databricks provider — used in two "modes" in this template:
    #   1. account mode  (alias = databricks.mws) -> talks to accounts.cloud.databricks.com
    #   2. workspace mode (default provider)       -> talks to the workspace we just created
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.116" # matches the version proven in .terraform.lock.hcl
    }

    # AWS provider — creates the IAM, VPC, and S3 resources Databricks needs.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Random — used to generate a unique suffix so names don't collide.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}
