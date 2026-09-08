output "s3_bucket_name" {
  description = "S3 bucket holding the site content. Used by the deploy-site.yml GitHub Actions workflow."
  value       = aws_s3_bucket.site.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Used by deploy-site.yml to create cache invalidations after each deploy."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "Default CloudFront domain (dxxxxxxxxxxxxx.cloudfront.net)."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "website_url" {
  description = "Public URL for the site."
  value       = local.use_domain ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "github_actions_role_arn" {
  description = "IAM role ARN GitHub Actions assumes via OIDC. Set as the AWS_ROLE_ARN repo variable/secret."
  value       = aws_iam_role.github_actions.arn
}
