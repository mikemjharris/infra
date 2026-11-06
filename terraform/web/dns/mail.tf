# Google Workspace mail. These must survive anything else that happens here.

resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "MX"
  ttl     = 3600
  records = [
    "1 aspmx.l.google.com",
    "5 alt1.aspmx.l.google.com",
    "5 alt2.aspmx.l.google.com",
    "10 alt3.aspmx.l.google.com",
    "10 alt4.aspmx.l.google.com",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

# Only Google may send mail as the domain. Soft fail (~all) to start.
resource "aws_route53_record" "spf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "TXT"
  ttl     = 3600
  records = ["v=spf1 include:_spf.google.com ~all"]
}

# Monitoring only (p=none) until SPF and DKIM are confirmed working; then
# tighten to quarantine.
resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "_dmarc.${var.domain}"
  type    = "TXT"
  ttl     = 3600
  records = [join("; ", compact([
    "v=DMARC1",
    "p=none",
    var.dmarc_report_email != "" ? "rua=mailto:${var.dmarc_report_email}" : "",
  ]))]
}

resource "aws_route53_record" "dkim" {
  count = var.google_dkim_record != "" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "google._domainkey.${var.domain}"
  type    = "TXT"
  ttl     = 3600
  # TXT strings are limited to 255 characters; DKIM keys are split.
  records = [join("\"\"", regexall(".{1,255}", var.google_dkim_record))]
}
