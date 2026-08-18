###############################################################################
# bootstrap/main.tf
# -----------------------------------------------------------------------------
# ONE-TIME setup that creates the remote-state backing store used by the main
# template: an S3 bucket (state storage, versioned + encrypted) and a DynamoDB
# table (state locking). Run this FIRST if you want remote state.
#
# This bootstrap itself uses LOCAL state — that's fine, it only creates two
# durable resources you rarely change.
#
# Usage:
#   cd aws/bootstrap
#   terraform init
#   terraform apply -var="aws_region=us-west-2" -var="name_prefix=dbx"
#   # note the outputs, then fill them into ../backend.tf and run
#   # `terraform init -migrate-state` in ../
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "name_prefix" {
  type        = string
  default     = "dbx"
  description = "Prefix for the state bucket and lock table."
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Random suffix so the globally-unique bucket name doesn't collide.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "aws_s3_bucket" "tfstate" {
  bucket        = "${var.name_prefix}-tfstate-${random_string.suffix.result}"
  force_destroy = false # protect state; flip to true only if you really mean it.
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled" # keep history of state files for recovery.
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tflock" {
  name         = "${var.name_prefix}-tflock-${random_string.suffix.result}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# These two values go into ../backend.tf
output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "lock_table" {
  value = aws_dynamodb_table.tflock.name
}
