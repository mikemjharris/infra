# The app runs unchanged inside Lambda: the image includes the AWS Lambda Web
# Adapter, which turns Lambda invocations into ordinary HTTP requests.

locals {
  enabled = var.image_uri != ""
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

resource "aws_iam_role" "function" {
  name               = "${var.name}-function"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "function_logs" {
  role       = aws_iam_role.function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "site" {
  count = local.enabled ? 1 : 0

  function_name = var.name
  role          = aws_iam_role.function.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["x86_64"]
  memory_size   = var.memory_mb
  timeout       = var.timeout_seconds

  environment {
    variables = var.environment
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.function.name
  }

  lifecycle {
    # Deploys from the site's repo update the image.
    ignore_changes = [image_uri]
  }

  depends_on = [aws_iam_role_policy_attachment.function_logs]
}

# Only CloudFront uses this address; it isn't published anywhere. Creating a
# NONE-auth URL also adds the lambda:InvokeFunctionUrl permission itself.
resource "aws_lambda_function_url" "site" {
  count = local.enabled ? 1 : 0

  function_name      = aws_lambda_function.site[0].function_name
  authorization_type = "NONE"
}

# Public URLs also need lambda:InvokeFunction, limited to calls arriving
# through the URL so the function can't be invoked directly.
resource "aws_lambda_permission" "url_invoke" {
  count = local.enabled ? 1 : 0

  statement_id             = "FunctionURLAllowInvokeAction"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.site[0].function_name
  principal                = "*"
  invoked_via_function_url = true
}

locals {
  function_url_host = local.enabled ? trimsuffix(trimprefix(aws_lambda_function_url.site[0].function_url, "https://"), "/") : ""
}
