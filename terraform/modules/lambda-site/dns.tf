# A/AAAA aliases to CloudFront. allow_overwrite replaces an existing A record
# (e.g. the old server's) in one Route 53 update, so there's no gap.

resource "aws_route53_record" "alias" {
  for_each = local.enabled && var.serve_dns ? toset(flatten([for d in var.domain_names : ["${d}|A", "${d}|AAAA"]])) : toset([])

  zone_id         = var.zone_id
  name            = split("|", each.key)[0]
  type            = split("|", each.key)[1]
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.site[0].domain_name
    zone_id                = aws_cloudfront_distribution.site[0].hosted_zone_id
    evaluate_target_health = false
  }
}
