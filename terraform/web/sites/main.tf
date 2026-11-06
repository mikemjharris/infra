data "aws_route53_zone" "main" {
  name = var.domain
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# www.mikemjharris.com, plus the apex redirecting to it.
module "www" {
  source = "../../modules/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name         = "www"
  domain_names = ["www.${var.domain}", var.domain]
  zone_id      = data.aws_route53_zone.main.zone_id
  bucket_name  = "mikemjharris-www-${var.web_account_id}"

  not_found_page = "/404.html"

  # Still served by the droplet (web/dns). Cut over by removing www and the
  # apex from web/dns and setting this true.
  serve_dns = false

  github_repo              = "mikemjharris/personal-website"
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
}
