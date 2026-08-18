###############################################################################
# network.tf
# -----------------------------------------------------------------------------
# The VPC that Databricks compute runs in ("customer-managed VPC"). We use the
# community-standard terraform-aws-modules/vpc module to keep this short and
# correct, then register the network with the Databricks account.
#
# Databricks requirements captured here:
#   * At least 2 private subnets in different Availability Zones.
#   * A NAT gateway so clusters can reach the Databricks control plane / PyPI.
#   * A security group allowing all-internal traffic + all egress.
#   * VPC endpoints (S3 gateway, STS, Kinesis) to keep traffic on the AWS
#     backbone and reduce NAT cost.
###############################################################################

# Discover which AZs exist in the chosen region so subnets land correctly.
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = var.cidr_block

  # Use the first 3 AZs the region offers (regions vary: some have 3, some 6).
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true # one NAT keeps cost down for a starter; use one-per-AZ for prod HA.
  create_igw           = true

  # One public subnet for the NAT gateway; two private subnets for clusters.
  public_subnets = [cidrsubnet(var.cidr_block, 3, 0)]
  private_subnets = [
    cidrsubnet(var.cidr_block, 3, 1),
    cidrsubnet(var.cidr_block, 3, 2),
  ]

  # Security group Databricks will use for the workspace network.
  manage_default_security_group = true
  default_security_group_name   = "${local.name}-sg"

  default_security_group_egress = [{
    description = "Allow all outbound"
    cidr_blocks = "0.0.0.0/0"
  }]

  default_security_group_ingress = [{
    description = "Allow all internal TCP and UDP within the security group"
    self        = true
  }]

  tags = local.tags
}

# VPC endpoints keep S3/STS/Kinesis traffic private and cheaper than via NAT.
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id]

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids,
      ])
      tags = { Name = "${local.name}-s3-endpoint" }
    }
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "${local.name}-sts-endpoint" }
    }
    kinesis-streams = {
      service             = "kinesis-streams"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags                = { Name = "${local.name}-kinesis-endpoint" }
    }
  }

  tags = local.tags
}

# Register the VPC with the Databricks account as a "network configuration".
resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${local.name}-network"
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id
}
