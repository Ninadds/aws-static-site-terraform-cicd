variable "project_name" {
  description = "Short name used to prefix/tag all resources (lowercase, hyphenated)."
  type        = string
  default     = "ninad-static-site"
}

variable "environment" {
  description = "Deployment environment name, e.g. dev, staging, prod."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for the S3 bucket and non-global resources."
  type        = string
  default     = "eu-west-2" # London
}

variable "domain_name" {
  description = <<-EOT
    Optional custom domain for the site, e.g. "portfolio.example.com".
    Leave as an empty string to skip ACM + Route 53 and just use the
    auto-generated CloudFront domain (dxxxxxxxxxxxxx.cloudfront.net).
  EOT
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID that owns domain_name. Required only if domain_name is set."
  type        = string
  default     = ""
}

variable "index_document" {
  description = "S3/CloudFront default root object."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Object returned for 404s."
  type        = string
  default     = "error.html"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class. PriceClass_100 = US/Canada/Europe only (cheapest)."
  type        = string
  default     = "PriceClass_100"
}

# ---------------------------------------------------------------------------
# GitHub OIDC (used so GitHub Actions can assume an AWS role without storing
# long-lived AWS access keys as secrets).
# ---------------------------------------------------------------------------

variable "github_org" {
  description = "GitHub org or username that owns the repo, e.g. \"Ninadds\"."
  type        = string
  default     = "Ninadds"
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)."
  type        = string
  default     = "aws-static-site-terraform-cicd"
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    Whether to create the GitHub Actions OIDC provider in this AWS account.
    Set to false if your account already has one (an AWS account can only
    have a single OIDC provider per URL) - see README troubleshooting.
  EOT
  type        = bool
  default     = true
}
