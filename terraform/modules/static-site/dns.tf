resource "aws_route53_record" "alias" {
  for_each = var.serve_dns ? toset(flatten([for d in var.domain_names : ["${d}|A", "${d}|AAAA"]])) : toset([])

  zone_id = var.zone_id
  name    = split("|", each.key)[0]
  type    = split("|", each.key)[1]

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
