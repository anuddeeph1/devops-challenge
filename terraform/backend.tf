# Terraform Backend Configuration for Remote State
# This configuration stores Terraform state in S3 with DynamoDB locking

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.tags,
    {
      Name        = "${var.project_name}-terraform-state"
      Description = "Terraform remote state storage"
    }
  )

  lifecycle {
    prevent_destroy = false # Set to true in production
  }
}

# Enable versioning for state history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {} # Empty filter applies to all objects

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    local.tags,
    {
      Name        = "${var.project_name}-terraform-locks"
      Description = "Terraform state locking"
    }
  )

  lifecycle {
    prevent_destroy = false # Set to true in production
  }
}

# Backend Configuration
# After initial apply, uncomment the below and run 'terraform init -migrate-state'
# to migrate local state to S3 backend

/*
terraform {
  backend "s3" {
    bucket         = "simpletimeservice-terraform-state-<YOUR-ACCOUNT-ID>"
    key            = "prod/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "simpletimeservice-terraform-locks"
    encrypt        = true
  }
}
*/

# Output backend configuration for easy setup
output "backend_config" {
  description = "Backend configuration to add to versions.tf after initial apply"
  value       = <<-EOT
    Add this to your backend.tf and run 'terraform init -migrate-state':

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "prod/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
        encrypt        = true
      }
    }
  EOT
}

