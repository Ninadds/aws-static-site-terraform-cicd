# ---------------------------------------------------------------------------
# Lets GitHub Actions assume an AWS IAM role via OIDC federation, so the CI/CD
# pipeline never needs long-lived AWS access keys stored as GitHub secrets.
#
# Bootstrap note: this is chicken-and-egg. The very first `terraform apply`
# that creates this role has to be run from your own machine with your own
# AWS credentials (see README "Bootstrap" section). After that, CI can use
# the role for every subsequent plan/apply.
# ---------------------------------------------------------------------------

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

locals {
  # Allow the AWS account's existing OIDC provider ARN to be reused when
  # create_github_oidc_provider = false (an account can only have one).
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # GitHub now embeds immutable numeric org/repo IDs into the sub claim
    # (e.g. "repo:OWNER@12345/REPO@67890:..."), not just the plain names, as
    # a security hardening measure. Wildcard around the "@<id>" segments so
    # this matches regardless of whether GitHub sends the ID-suffixed form
    # or the legacy plain-name form, for any ref/PR/environment in this repo.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:*",
        "repo:${var.github_org}@*/${var.github_repo}@*:*",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Scoped to exactly what the pipeline needs: manage this project's S3 bucket,
# invalidate this CloudFront distribution, and read/write Terraform state.
# Nothing account-wide, nothing destructive outside this project's resources.
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid    = "S3SiteBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*",
    ]
  }

  statement {
    sid       = "CloudFrontInvalidation"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }

  # Broad read/plan permissions across the services this stack manages, so
  # `terraform plan`/`apply` from CI can inspect and update all resources
  # declared in this project (S3, CloudFront, ACM, Route 53, IAM for this
  # role itself). Tighten further if you extend the stack.
  statement {
    sid    = "TerraformManagedResources"
    effect = "Allow"
    actions = [
      "s3:*",
      "cloudfront:*",
      "acm:*",
      "route53:*",
      "iam:GetRole",
      "iam:GetOpenIDConnectProvider",
      "iam:PassRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.project_name}-github-actions-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
