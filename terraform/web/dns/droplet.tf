# Records for sites still on the DigitalOcean droplet, copied from the zone
# there so switching nameservers changes nothing. Short TTLs so each move to
# CloudFront takes effect quickly. Shrinks to nothing as the sites move.

resource "aws_route53_record" "droplet_apex" {
  count = var.droplet_serves_apex ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 300
  records = [var.droplet_ip]
}

resource "aws_route53_record" "droplet_hosts" {
  for_each = var.droplet_hosts

  zone_id = aws_route53_zone.main.zone_id
  name    = "${each.key}.${var.domain}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain]
}
