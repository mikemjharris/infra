# Guard rails for every account in the workloads OU. SCPs never apply to the
# management account itself.

data "aws_iam_policy_document" "workloads_guardrails" {
  statement {
    sid       = "DenyLeavingOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  # Member accounts are reached through SSO; their root users are only for
  # account recovery, which goes through the management account.
  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }

  # Global services are exempt: their API calls are made in us-east-1 or have
  # no region.
  statement {
    sid    = "DenyOtherRegions"
    effect = "Deny"
    not_actions = [
      "account:*",
      "acm:*",
      "budgets:*",
      "ce:*",
      "cloudfront:*",
      "cur:*",
      "health:*",
      "iam:*",
      "organizations:*",
      "pricing:*",
      "route53:*",
      "route53domains:*",
      "s3:GetAccountPublicAccessBlock",
      "s3:ListAllMyBuckets",
      "s3:PutAccountPublicAccessBlock",
      "shield:*",
      "sso:*",
      "sts:*",
      "support:*",
      "tag:*",
      "trustedadvisor:*",
      "waf:*",
      "wafv2:*",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

resource "aws_organizations_policy" "workloads_guardrails" {
  name        = "workloads-guardrails"
  description = "No leaving the org, no root user, only allowed regions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.workloads_guardrails.json

  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_policy_attachment" "workloads_guardrails" {
  policy_id = aws_organizations_policy.workloads_guardrails.id
  target_id = aws_organizations_organizational_unit.workloads.id
}
