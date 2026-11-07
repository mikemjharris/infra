# Cost kill switch: when this account's spend for the month passes
# kill_switch_usd, AWS Budgets notifies an SNS topic and a function throttles
# every Lambda function here to zero, so a flood of requests to the blog can't
# run up a bill. CloudFront keeps serving the static sites and cached pages.
#
# Billing data lags by hours, so this bounds the damage rather than capping it
# exactly. terraform/org adds a harder stop (an SCP) at a higher amount.
#
# Undo, per function:  aws lambda delete-function-concurrency --function-name blog
# Test without effect: aws lambda invoke --function-name budget-kill-switch \
#                        --payload '{"dry_run":true}' --cli-binary-format raw-in-base64-out /dev/stdout

resource "aws_sns_topic" "kill_switch" {
  name = "budget-kill-switch"
}

data "aws_iam_policy_document" "kill_switch_topic" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.kill_switch.arn]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.web_account_id]
    }
  }
}

resource "aws_sns_topic_policy" "kill_switch" {
  arn    = aws_sns_topic.kill_switch.arn
  policy = data.aws_iam_policy_document.kill_switch_topic.json
}

resource "aws_budgets_budget" "kill_switch" {
  name         = "kill-switch"
  budget_type  = "COST"
  limit_amount = tostring(var.kill_switch_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.kill_switch.arn]
  }

  depends_on = [aws_sns_topic_policy.kill_switch]
}

data "archive_file" "kill_switch" {
  type        = "zip"
  source_file = "${path.module}/kill-switch/index.py"
  output_path = "${path.module}/.build/kill-switch.zip"
  # Same zip, so same hash, wherever it is built (checkouts differ in modes).
  output_file_mode = "0644"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# The name is exempt from terraform/org's web-freeze SCP.
resource "aws_iam_role" "kill_switch" {
  name               = "budget-kill-switch"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "kill_switch_logs" {
  role       = aws_iam_role.kill_switch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "kill_switch" {
  statement {
    actions   = ["lambda:ListFunctions"]
    resources = ["*"]
  }

  statement {
    actions   = ["lambda:PutFunctionConcurrency"]
    resources = ["arn:aws:lambda:*:${var.web_account_id}:function:*"]
  }
}

resource "aws_iam_role_policy" "kill_switch" {
  name   = "throttle-functions"
  role   = aws_iam_role.kill_switch.id
  policy = data.aws_iam_policy_document.kill_switch.json
}

resource "aws_cloudwatch_log_group" "kill_switch" {
  name              = "/aws/lambda/budget-kill-switch"
  retention_in_days = 90
}

resource "aws_lambda_function" "kill_switch" {
  function_name    = "budget-kill-switch"
  role             = aws_iam_role.kill_switch.arn
  runtime          = "python3.13"
  handler          = "index.handler"
  architectures    = ["arm64"]
  timeout          = 60
  filename         = data.archive_file.kill_switch.output_path
  source_code_hash = data.archive_file.kill_switch.output_base64sha256

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.kill_switch.name
  }

  depends_on = [aws_iam_role_policy_attachment.kill_switch_logs]
}

resource "aws_sns_topic_subscription" "kill_switch" {
  topic_arn = aws_sns_topic.kill_switch.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.kill_switch.arn
}

resource "aws_lambda_permission" "kill_switch_sns" {
  statement_id  = "AllowBudgetTopic"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kill_switch.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.kill_switch.arn
}
