# Lets GitHub Actions log in to this account with short-lived tokens, so no
# AWS keys are stored in GitHub. Each role below says which repo, and which
# branch or environment within it, may assume it.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  infra_repo = "${var.github_owner}/${var.infra_repo}"
  # The OIDC subject prefix for this repo (immutable form, with IDs).
  infra_sub = "repo:${var.github_owner}@${var.github_owner_id}/${var.infra_repo}@${var.infra_repo_id}"
}

# --- plan: read-only, for pull requests and scheduled drift checks ---------

data "aws_iam_policy_document" "infra_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.infra_sub}:pull_request",
        "${local.infra_sub}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "infra_plan" {
  name                 = "github-infra-plan"
  description          = "terraform plan from GitHub Actions in ${local.infra_repo}"
  assume_role_policy   = data.aws_iam_policy_document.infra_plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "infra_plan_readonly" {
  role       = aws_iam_role.infra_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan reads state and takes the S3 lock file; it never writes state itself.
data "aws_iam_policy_document" "infra_plan_state" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "infra_plan_state" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.infra_plan.id
  policy = data.aws_iam_policy_document.infra_plan_state.json
}

# --- apply: admin in this account, only from the production environment ----

data "aws_iam_policy_document" "infra_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Jobs using the `production` environment, which only runs on main.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.infra_sub}:environment:production"]
    }
  }
}

resource "aws_iam_role" "infra_apply" {
  name                 = "github-infra-apply"
  description          = "terraform apply from GitHub Actions in ${local.infra_repo} (production environment)"
  assume_role_policy   = data.aws_iam_policy_document.infra_apply_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "infra_apply_admin" {
  role       = aws_iam_role.infra_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
