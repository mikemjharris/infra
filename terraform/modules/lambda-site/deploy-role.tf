# Lets the site's own repo push images, point the function at a new image and
# clear the cache, and nothing else, from GitHub Actions on its main branch.

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
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.site.arn]
  }

  statement {
    actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction", "lambda:GetFunctionConfiguration"]
    resources = ["arn:aws:lambda:*:*:function:${var.name}"]
  }

  statement {
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = local.enabled ? [aws_cloudfront_distribution.site[0].arn] : ["arn:aws:cloudfront::*:distribution/none"]
  }
}

resource "aws_iam_role" "deploy" {
  count = var.github_repo != "" ? 1 : 0

  name                 = "github-deploy-${var.name}"
  description          = "Image deploys for ${var.domain_names[0]} from ${var.github_repo}"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust[0].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "deploy" {
  count = var.github_repo != "" ? 1 : 0

  name   = "deploy"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy[0].json
}
