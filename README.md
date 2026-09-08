# AWS Static Site — Terraform + CI/CD from Scratch

A small, complete portfolio project: a static website hosted on AWS, with its
entire infrastructure defined in Terraform and its entire deploy process
automated with GitHub Actions. No manual clicking in the AWS console, no
manually-run `terraform apply` after the first bootstrap, no long-lived AWS
keys sitting in GitHub secrets.

## Architecture

```
                     ┌─────────────────────┐
  GitHub push/PR ───▶│   GitHub Actions     │
                     │  (OIDC → AWS role)   │
                     └─────────┬───────────┘
                               │
                 ┌─────────────┴─────────────┐
                 │                            │
        terraform plan/apply           aws s3 sync + invalidate
                 │                            │
                 ▼                            ▼
        ┌─────────────────┐          ┌──────────────────┐
        │  AWS resources   │          │   S3 bucket       │
        │  (S3, CF, ACM,   │◀─────────│  (site content)   │
        │  Route53, IAM)   │  origin  └──────────────────┘
        └────────┬─────────┘
                 │
                 ▼
        ┌──────────────────┐
        │   CloudFront      │──▶ https://<domain or *.cloudfront.net>
        │ (HTTPS, caching)  │
        └──────────────────┘
```

- **S3** stores the site files. The bucket is fully private — public access
  is blocked at the bucket level.
- **CloudFront** is the only thing allowed to read from the bucket, enforced
  via an Origin Access Control (OAC) + bucket policy condition on the
  distribution's ARN.
- **ACM + Route 53** are wired up but fully optional — leave `domain_name`
  blank in `terraform.tfvars` and the site is served straight off the
  CloudFront default domain with no custom certificate needed.
- **IAM + OIDC** lets GitHub Actions assume a scoped AWS role for the
  duration of a workflow run, using a short-lived token — no `AWS_ACCESS_KEY_ID`
  / `AWS_SECRET_ACCESS_KEY` secrets anywhere in this repo.

## Repo layout

```
terraform/
  versions.tf          # provider requirements, backend block (commented)
  variables.tf          # all configurable inputs
  main.tf                # S3, CloudFront, OAC, ACM, Route 53
  github-oidc.tf         # OIDC provider + IAM role/policy for CI
  outputs.tf              # bucket name, distribution ID, site URL, role ARN
  terraform.tfvars.example
.github/workflows/
  terraform.yml         # fmt, validate, plan (on PR), apply (on merge to main)
  deploy-site.yml       # syncs site/ to S3 + invalidates CloudFront cache
site/
  index.html, error.html, assets/style.css   # the actual website
```

## Prerequisites

- An AWS account and the AWS CLI configured locally (`aws configure`) —
  only needed for the one-time bootstrap step below.
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6
- A GitHub repo you can push this project to.

## Bootstrap (one-time, run locally)

The pipeline needs an IAM role to exist before it can do anything — and that
role is itself created by Terraform. So the very first apply has to run from
your machine with your own AWS credentials; every apply after that can run
from CI.

1. **Copy and edit the tfvars file:**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```
   Fill in `github_org` / `github_repo` to match where you push this project.
   Leave `domain_name` and `hosted_zone_id` blank unless you own a domain and
   have a Route 53 hosted zone for it.

2. **Initialize and apply:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Grab the outputs you'll need for GitHub:**
   ```bash
   terraform output
   ```
   You'll need `github_actions_role_arn`, `s3_bucket_name`, and
   `cloudfront_distribution_id`.

4. **In your GitHub repo → Settings → Secrets and variables → Actions →
   Variables tab**, add:
   | Name | Value |
   |---|---|
   | `AWS_ROLE_ARN` | `github_actions_role_arn` output |
   | `S3_BUCKET_NAME` | `s3_bucket_name` output |
   | `CLOUDFRONT_DISTRIBUTION_ID` | `cloudfront_distribution_id` output |

   (Plain repo *variables* are fine here — none of these three values are
   secret; they're resource identifiers, not credentials.)

5. **Push to `main`.** From here on:
   - Editing anything under `terraform/` triggers `terraform.yml` — a plan
     is posted as a PR comment, and merging to `main` auto-applies it.
   - Editing anything under `site/` triggers `deploy-site.yml` — it syncs
     the files to S3 and invalidates the CloudFront cache so changes go
     live within a minute or two.

6. Visit the `website_url` Terraform output — that's your live site.

## Remote state (optional, recommended before you rely on this long-term)

By default this uses local Terraform state, which is fine to get started but
means "state lives on whichever machine last ran apply." For a project you
intend to keep evolving, bootstrap a small S3 bucket + DynamoDB lock table
for remote state, then uncomment the `backend "s3" { ... }` block in
`versions.tf` and run `terraform init -migrate-state`.

## Notes / things worth knowing for interviews

- **OAC over OAI**: this uses CloudFront Origin Access Control, the current
  AWS-recommended way to lock an S3 origin to CloudFront (OAI is legacy).
- **Least privilege, scoped by repo/branch**: the IAM role's trust policy
  restricts `AssumeRoleWithWebIdentity` to this specific repo, and to either
  the `main` branch or pull request events — a fork of this repo cannot
  assume the role.
- **Plan on PR, apply on merge**: nothing touches real infrastructure until
  a PR is reviewed and merged, and every proposed change is visible as a
  plan comment before that happens.
- **Two independent pipelines**: infrastructure changes and content changes
  deploy independently, so pushing a copy edit to `site/` doesn't trigger a
  Terraform run and vice versa.

## Cleanup

To tear everything down and stop any AWS charges:
```bash
cd terraform
terraform destroy
```
Note the S3 bucket has versioning enabled — if it isn't empty, `destroy` may
need you to empty all object versions first (`aws s3 rm s3://<bucket> --recursive`).
