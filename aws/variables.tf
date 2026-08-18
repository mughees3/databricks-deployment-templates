###############################################################################
# variables.tf
# -----------------------------------------------------------------------------
# Every input the template accepts, grouped by purpose. Non-secret values go in
# terraform.tfvars (copy from terraform.tfvars.example). SECRETS go in
# environment variables (TF_VAR_<name>) and are marked `sensitive = true`.
###############################################################################

# ---------------------------------------------------------------------------
# Databricks account credentials (SECRETS — supply via TF_VAR_ env vars)
# ---------------------------------------------------------------------------
variable "databricks_account_id" {
  type        = string
  description = "Databricks Account ID (find it in the account console, top-right menu)."
}

variable "databricks_client_id" {
  type        = string
  description = "OAuth service-principal client ID for the Databricks ACCOUNT API."
  sensitive   = true
}

variable "databricks_client_secret" {
  type        = string
  description = "OAuth service-principal secret for the Databricks ACCOUNT API. Provide via TF_VAR_databricks_client_secret."
  sensitive   = true
}

# ---------------------------------------------------------------------------
# AWS settings
# ---------------------------------------------------------------------------
variable "aws_region" {
  type        = string
  description = "AWS region to deploy into, e.g. us-west-2, us-east-1, ap-southeast-2."
  default     = "us-west-2"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile to use. Leave null to use the default credential chain (env vars / SSO / CI role)."
  default     = null
}

# ---------------------------------------------------------------------------
# Naming & tagging
# ---------------------------------------------------------------------------
variable "prefix" {
  type        = string
  description = "Short prefix for all resource names (lowercase letters/numbers). A random suffix is appended for uniqueness."
  default     = "dbx"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,10}$", var.prefix))
    error_message = "prefix must be 2-11 chars, lowercase letters/numbers, starting with a letter."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all AWS resources. Add Owner/Environment/CostCenter as your org requires."
  default     = {}
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "cidr_block" {
  type        = string
  description = "CIDR range for the VPC Databricks runs in. Must be /16–/25 and not overlap peers."
  default     = "10.4.0.0/16"
}

# ---------------------------------------------------------------------------
# Unity Catalog
# ---------------------------------------------------------------------------
variable "create_metastore" {
  type        = bool
  description = "Create a new Unity Catalog metastore in this region. Set false if your account ALREADY has a metastore in this region (only one per region is allowed) — the template will just assign the existing one if you supply existing_metastore_id."
  default     = true
}

variable "existing_metastore_id" {
  type        = string
  description = "If create_metastore = false, the ID of the existing regional metastore to assign to this workspace."
  default     = null
}

variable "catalog_name" {
  type        = string
  description = "Name of the starter Unity Catalog catalog to create for this workspace."
  default     = "main_demo"
}

# ---------------------------------------------------------------------------
# Starter in-workspace resources (set any to false to skip)
# ---------------------------------------------------------------------------
variable "create_sql_warehouse" {
  type        = bool
  description = "Create a small SQL warehouse so users can query immediately."
  default     = true
}

variable "sql_warehouse_serverless" {
  type        = bool
  description = "Use serverless SQL compute for the starter warehouse (the recommended, showable default). Requires serverless SQL to be ENABLED for the account/region — set false to fall back to classic (PRO) compute if serverless isn't available."
  default     = true
}

variable "workspace_admins" {
  type        = list(string)
  description = "Email addresses to grant workspace admin. These users must already exist at the account level (or will be invited)."
  default     = []
}
