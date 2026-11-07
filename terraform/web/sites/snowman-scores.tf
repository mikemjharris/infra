# The snowman game's shared high-score table: a DynamoDB table and a small
# function, served by snowman's CloudFront at /api/scores. The function URL
# refuses requests without CloudFront's secret header.

resource "aws_dynamodb_table" "snowman_scores" {
  name         = "snowman-scores"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "board"
  range_key    = "rank"

  # board: always "all". rank: the zero-padded score plus a unique suffix, so
  # a descending query returns the top scores.
  attribute {
    name = "board"
    type = "S"
  }

  attribute {
    name = "rank"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "random_password" "snowman_scores_origin_verify" {
  length  = 40
  special = false
}

data "archive_file" "snowman_scores" {
  type        = "zip"
  source_file = "${path.module}/snowman-scores/index.mjs"
  output_path = "${path.module}/.build/snowman-scores.zip"
}

data "aws_iam_policy_document" "snowman_scores_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "snowman_scores" {
  name               = "snowman-scores-function"
  assume_role_policy = data.aws_iam_policy_document.snowman_scores_trust.json
}

resource "aws_iam_role_policy_attachment" "snowman_scores_logs" {
  role       = aws_iam_role.snowman_scores.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "snowman_scores" {
  statement {
    actions   = ["dynamodb:Query", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.snowman_scores.arn]
  }
}

resource "aws_iam_role_policy" "snowman_scores" {
  name   = "scores-table"
  role   = aws_iam_role.snowman_scores.id
  policy = data.aws_iam_policy_document.snowman_scores.json
}

resource "aws_cloudwatch_log_group" "snowman_scores" {
  name              = "/aws/lambda/snowman-scores"
  retention_in_days = 14
}

resource "aws_lambda_function" "snowman_scores" {
  function_name    = "snowman-scores"
  role             = aws_iam_role.snowman_scores.arn
  runtime          = "nodejs24.x"
  handler          = "index.handler"
  architectures    = ["arm64"]
  memory_size      = 256
  timeout          = 5
  filename         = data.archive_file.snowman_scores.output_path
  source_code_hash = data.archive_file.snowman_scores.output_base64sha256

  environment {
    variables = {
      TABLE                = aws_dynamodb_table.snowman_scores.name
      ORIGIN_VERIFY_SECRET = random_password.snowman_scores_origin_verify.result
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.snowman_scores.name
  }

  depends_on = [aws_iam_role_policy_attachment.snowman_scores_logs]
}

resource "aws_lambda_function_url" "snowman_scores" {
  function_name      = aws_lambda_function.snowman_scores.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "snowman_scores_url_invoke" {
  statement_id             = "FunctionURLAllowInvokeAction"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.snowman_scores.function_name
  principal                = "*"
  invoked_via_function_url = true
}

locals {
  snowman_scores_host = trimsuffix(trimprefix(aws_lambda_function_url.snowman_scores.function_url, "https://"), "/")
}
