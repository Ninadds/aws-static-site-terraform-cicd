terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote state (recommended once you've bootstrapped an S3 bucket + DynamoDB
  # lock table for state). Left commented so the project runs with local state
  # out of the box. See README.md "Remote state" section to enable this.
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "REPLACE-ME-terraform-state-bucket"
  #   key            = "static-site/terraform.tfstate"
  #   region         = "eu-west-2"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

# Primary provider - used for the S3 bucket and (optionally) Route 53 records.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront requires ACM certificates for custom domains to exist in
# us-east-1, regardless of where the rest of the stack lives. This aliased
# provider is only used by the aws_acm_certificate resource below.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
