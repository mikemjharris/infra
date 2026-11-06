# Points the hostnames at CloudFront once serve_dns is on. allow_overwrite
# replaces any existing record of the same name and type in one Route 53
# update (UPSERT), so taking over a name from the old server has no gap.
# The zone apex can't be a CNAME, so it gets A/AAAA aliases; other names get
# a CNAME, which also overwrites an existing CNAME in place.

data "aws_route53_zone" "this" {
  zone_id = var.zone_id
}

locals {
  apex_names = [for d in var.domain_names : d if d == trimsuffix(data.aws_route53_zone.this.name, ".")]
  sub_names  = [for d in var.domain_names : d if !contains(local.apex_names, d)]

  alias_records = var.serve_dns ? toset(flatten([for d in local.apex_names : ["${d}|A", "${d}|AAAA"]])) : toset([])
}

resource "aws_route53_record" "apex" {
  for_each = local.alias_records

  zone_id         = var.zone_id
  name            = split("|", each.key)[0]
  type            = split("|", each.key)[1]
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "sub" {
  for_each = var.serve_dns ? toset(local.sub_names) : toset([])

  zone_id         = var.zone_id
  name            = each.key
  type            = "CNAME"
  ttl             = 300
  records         = [aws_cloudfront_distribution.site.domain_name]
  allow_overwrite = true
}
