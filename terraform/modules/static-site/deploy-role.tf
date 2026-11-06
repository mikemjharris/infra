# Lets the site's own repo upload content and clear the cache, and nothing
# else, from GitHub Actions on its main branch.

data "aws_iam_policy_document" "deploy_trust" {
  count = var.github_repo != "" ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

data "aws_iam_policy_document" "deploy" {
  count = var.github_repo != "" ? 1 : 0

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role" "deploy" {
  count = var.github_repo != "" ? 1 : 0

  name                 = "github-deploy-${var.name}"
  description          = "Content deploys for ${var.domain_names[0]} from ${var.github_repo}"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust[0].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "deploy" {
  count = var.github_repo != "" ? 1 : 0

  name   = "deploy"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy[0].json
}
