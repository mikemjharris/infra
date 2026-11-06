# The zone outlives everything else in the web account. A reusable
# delegation set fixes its four nameservers, so even a deleted and recreated
# zone keeps the same ones and the registrar never needs updating.

resource "aws_route53_delegation_set" "main" {
  reference_name = var.domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "main" {
  name              = var.domain
  comment           = "Managed by mikemjharris/infra (web/dns)"
  delegation_set_id = aws_route53_delegation_set.main.id

  lifecycle {
    prevent_destroy = true
  }
}

# Only certificate authorities used here may issue for the domain: Amazon
# (ACM, for CloudFront) and Let's Encrypt (the droplet, until it's retired).
resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "CAA"
  ttl     = 3600
  records = [
    "0 issue \"amazon.com\"",
    "0 issue \"letsencrypt.org\"",
    "0 issuewild \";\"",
  ]
}
