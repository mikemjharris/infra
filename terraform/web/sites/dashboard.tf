# www.mikemjharris.com/dashboard/: a static page, from mikemjharris/dashboard,
# showing each site's version.json. It lives in the www bucket, so its repo
# gets a role that can write only under dashboard/.

data "aws_iam_policy_document" "dashboard_deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:mikemjharris/dashboard:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "dashboard_deploy" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${module.www.bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["dashboard/*"]
    }
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${module.www.bucket}/dashboard/*"]
  }

  statement {
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = ["arn:aws:cloudfront::${var.web_account_id}:distribution/${module.www.distribution_id}"]
  }
}

resource "aws_iam_role" "dashboard_deploy" {
  name                 = "github-deploy-dashboard"
  description          = "Content deploys for www.${var.domain}/dashboard/ from mikemjharris/dashboard"
  assume_role_policy   = data.aws_iam_policy_document.dashboard_deploy_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "dashboard_deploy" {
  name   = "deploy"
  role   = aws_iam_role.dashboard_deploy.id
  policy = data.aws_iam_policy_document.dashboard_deploy.json
}
