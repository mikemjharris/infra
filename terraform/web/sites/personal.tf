# personal.mikemjharris.com: private pages behind Google sign-in, one folder
# per section, from a private repo. One Lambda serves the pages and the API,
# with data in DynamoDB. Only allowlisted Google accounts can sign in, and
# nothing but the sign-in page is served or cached without a session.
#
# Set up by hand before the first apply, once (both plain String parameters,
# kept out of this public repo):
#   aws ssm put-parameter --profile web --type String --name /personal/allowed-emails --value 'me@example.com'
#   aws ssm put-parameter --profile web --type String --name /personal/google-client-id --value '....apps.googleusercontent.com'
# The client ID is a Google OAuth "Web application" client whose authorised
# JavaScript origin is https://personal.mikemjharris.com.

data "aws_ssm_parameter" "personal_allowed_emails" {
  name = "/personal/allowed-emails"
}

data "aws_ssm_parameter" "personal_google_client_id" {
  name = "/personal/google-client-id"
}

# Signs the app's session cookies.
resource "random_password" "personal_session" {
  length  = 48
  special = false
}

resource "aws_dynamodb_table" "personal" {
  name         = "personal"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  # Generic keys; the app decides what goes under each pk.
  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

module "personal" {
  source = "../../modules/lambda-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name         = "personal"
  domain_names = ["personal.${var.domain}"]
  zone_id      = data.aws_route53_zone.main.zone_id

  # Empty until the first image is pushed by hand to the repository this
  # creates; later deploys come from the app's repo and Terraform ignores them.
  image_uri = ""

  memory_mb       = 512
  timeout_seconds = 10

  environment = {
    TABLE            = aws_dynamodb_table.personal.name
    PUBLIC_ORIGIN    = "https://personal.${var.domain}"
    ALLOWED_EMAILS   = data.aws_ssm_parameter.personal_allowed_emails.value
    GOOGLE_CLIENT_ID = data.aws_ssm_parameter.personal_google_client_id.value
    SESSION_SECRET   = random_password.personal_session.result
  }

  # A new site, so CloudFront sends the header from the start.
  enforce_origin_verify = true

  # Never cached: the API and every section's pages, which need a session.
  # Only the sign-in page and its script and styles use the default cache.
  # A new section adds its folder here.
  uncached_paths = ["/api/*", "/health/*"]

  # A new name: nothing to overwrite.
  serve_dns = true

  github_repo              = var.personal_github_repo
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  version_json_headers_policy_id = aws_cloudfront_response_headers_policy.version_json.id
}

data "aws_iam_policy_document" "personal_table" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.personal.arn]
  }
}

resource "aws_iam_role_policy" "personal_table" {
  name   = "personal-table"
  role   = module.personal.function_role_name
  policy = data.aws_iam_policy_document.personal_table.json
}
