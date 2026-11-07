# Cost guards on top of the monthly budget (budget.tf). AWS has no hard spend
# cap, and billing data runs hours behind, so these are layered:
#
#   1. daily budget email        - a spike is noticed within a day
#   2. Cost Anomaly Detection    - unusual spend by service, emailed daily
#   3. web/bootstrap kill switch - at its threshold, the site functions are
#                                  throttled to zero (the blog returns errors)
#   4. web freeze (below)        - at web_freeze_usd, an SCP blocks every API
#                                  call in the web account
#
# Undo 4: detach the web-freeze policy from the web account (from this
# account, which SCPs never apply to). Undo 3: see web/bootstrap/kill-switch.tf.

resource "aws_budgets_budget" "daily" {
  name         = "organisation-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.daily_budget_usd)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

resource "aws_ce_anomaly_monitor" "services" {
  name              = "services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "email" {
  name             = "anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_alert_usd)]
    }
  }

  subscriber {
    type    = "EMAIL"
    address = var.budget_email
  }
}

# Denies everything in the account it's attached to, except the kill switch's
# own role, so throttling still works if both fire together.
data "aws_iam_policy_document" "web_freeze" {
  statement {
    sid       = "FreezeOverBudget"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:role/budget-kill-switch"]
    }
  }
}

resource "aws_organizations_policy" "web_freeze" {
  name        = "web-freeze"
  description = "Attached by AWS Budgets when the web account goes over budget; detach to undo"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.web_freeze.json

  depends_on = [aws_organizations_organization.this]
}

resource "aws_budgets_budget" "web_freeze" {
  name         = "web-freeze"
  budget_type  = "COST"
  limit_amount = tostring(var.web_freeze_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [aws_organizations_account.web.id]
  }
}

data "aws_iam_policy_document" "budgets_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.management_account_id]
    }
  }
}

data "aws_iam_policy_document" "budgets_action" {
  statement {
    actions = [
      "organizations:AttachPolicy",
      "organizations:DetachPolicy",
    ]
    resources = [
      aws_organizations_policy.web_freeze.arn,
      "arn:aws:organizations::${var.management_account_id}:account/${aws_organizations_organization.this.id}/${aws_organizations_account.web.id}",
    ]
  }

  statement {
    actions = [
      "organizations:DescribePolicy",
      "organizations:ListPolicies",
      "organizations:ListTargetsForPolicy",
      "organizations:DescribeOrganization",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "budgets_action" {
  name               = "budgets-web-freeze"
  assume_role_policy = data.aws_iam_policy_document.budgets_trust.json
}

resource "aws_iam_role_policy" "budgets_action" {
  name   = "attach-web-freeze"
  role   = aws_iam_role.budgets_action.id
  policy = data.aws_iam_policy_document.budgets_action.json
}

resource "aws_budgets_budget_action" "web_freeze" {
  budget_name        = aws_budgets_budget.web_freeze.name
  action_type        = "APPLY_SCP_POLICY"
  approval_model     = "AUTOMATIC"
  notification_type  = "ACTUAL"
  execution_role_arn = aws_iam_role.budgets_action.arn

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100
  }

  definition {
    scp_action_definition {
      policy_id  = aws_organizations_policy.web_freeze.id
      target_ids = [aws_organizations_account.web.id]
    }
  }

  subscriber {
    address           = var.budget_email
    subscription_type = "EMAIL"
  }
}
