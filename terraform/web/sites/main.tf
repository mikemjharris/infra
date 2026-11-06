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

  not_found_page  = "/404.html"
  subdomain_cname = true

  # Cut over from the droplet 2026-11-06: these records replaced the
  # droplet's in place; web/dns no longer manages www or the apex.
  serve_dns = true

  github_repo              = "mikemjharris/personal-website"
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
}

# books.mikemjharris.com: a static React app that reads a published Google
# Sheet in the browser.
module "books" {
  source = "../../modules/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name         = "books"
  domain_names = ["books.${var.domain}"]
  zone_id      = data.aws_route53_zone.main.zone_id
  bucket_name  = "mikemjharris-books-${var.web_account_id}"

  # Cut over from the droplet: the alias records replace web/dns's A record
  # in place.
  serve_dns = true

  github_repo              = "mikemjharris/books"
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
}

# snowman.mikemjharris.com: the three.js snowball game, static, high scores
# kept in the player's browser.
module "snowman" {
  source = "../../modules/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name         = "snowman"
  domain_names = ["snowman.${var.domain}"]
  zone_id      = data.aws_route53_zone.main.zone_id
  bucket_name  = "mikemjharris-snowman-${var.web_account_id}"

  # Still served by the droplet (web/dns).
  serve_dns = false

  github_repo              = "mikemjharris/threejs-snowman"
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
}

# animated-message.mikemjharris.com: the SVG animated message, static. Has no
# DNS record yet (it was down); serve_dns goes on once there's content.
module "animated_message" {
  source = "../../modules/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name         = "animated-message"
  domain_names = ["animated-message.${var.domain}"]
  zone_id      = data.aws_route53_zone.main.zone_id
  bucket_name  = "mikemjharris-animated-message-${var.web_account_id}"

  serve_dns = false

  github_repo              = "mikemjharris/svg-animation-with-node-server"
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
}

# blog.mikemjharris.com: the Express app from mikemjharris/blog on Lambda.
module "blog" {
  source = "../../modules/lambda-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name         = "blog"
  domain_names = ["blog.${var.domain}"]
  zone_id      = data.aws_route53_zone.main.zone_id

  # The first image, pushed by hand. Later deploys come from the blog repo
  # and Terraform ignores them.
  image_uri = "702167621683.dkr.ecr.eu-west-2.amazonaws.com/blog:803e6dd32a12b4d28373362e9b9afed1bfb35571"

  environment = {
    NODE_ENV = "production"
  }

  static_paths   = ["/dist/*", "/images/*", "/stylesheets/*", "/favicon.ico"]
  uncached_paths = ["/mcp", "/mcp/*"]

  # Cut over from the droplet: the alias records replace web/dns's A record
  # in place.
  serve_dns = true

  github_repo              = "mikemjharris/blog"
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
}
