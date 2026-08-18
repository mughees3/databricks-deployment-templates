###############################################################################
# outputs.tf
# -----------------------------------------------------------------------------
# Handy values printed after `terraform apply`. Retrieve later with
# `terraform output` (add -json for machine parsing).
###############################################################################

output "workspace_url" {
  description = "Log in here once the apply completes."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "workspace_id" {
  description = "Numeric Databricks workspace ID."
  value       = databricks_mws_workspaces.this.workspace_id
}

output "aws_region" {
  description = "Region everything was deployed into."
  value       = var.aws_region
}

output "metastore_id" {
  description = "Unity Catalog metastore assigned to the workspace."
  value       = local.metastore_id
}

output "catalog_name" {
  description = "Starter Unity Catalog catalog."
  value       = databricks_catalog.starter.name
}

output "sql_warehouse_id" {
  description = "Starter SQL warehouse ID (null if not created)."
  value       = var.create_sql_warehouse ? databricks_sql_endpoint.starter[0].id : null
}

output "vpc_id" {
  description = "The customer-managed VPC Databricks runs in."
  value       = module.vpc.vpc_id
}

output "root_bucket" {
  description = "Workspace root S3 bucket."
  value       = aws_s3_bucket.root.bucket
}

output "unity_catalog_bucket" {
  description = "Unity Catalog data S3 bucket."
  value       = aws_s3_bucket.uc.bucket
}
