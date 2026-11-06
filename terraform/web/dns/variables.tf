variable "web_account_id" {
  type    = string
  default = "702167621683"
}

variable "domain" {
  type    = string
  default = "mikemjharris.com"
}

variable "droplet_ip" {
  description = "The old DigitalOcean droplet, which serves the sites until each one moves to AWS."
  type        = string
  default     = "178.62.78.11"
}

variable "droplet_hosts" {
  description = <<-EOT
    Subdomains still served by the droplet, as CNAMEs to the apex like today.
    Remove each one when its site moves to CloudFront: the sites layer
    overwrites the record in place, then `terraform state rm` it here so this
    layer forgets it without deleting it. Only names that work today are listed: dead and leftover
    ones (instagram, star-wars-timeline, view-from-the-ra, multi-snowman,
    trents, b-reel, ssquaredconsulting, vhstube) and the stale `dev` record
    are not carried over.
  EOT
  type        = set(string)
  default     = ["blog", "books", "snowman", "webhook"]
}

variable "droplet_serves_apex" {
  description = "Whether the apex still points at the droplet. www and the apex moved to CloudFront (web/sites) on 2026-11-06."
  type        = bool
  default     = false
}

variable "google_dkim_record" {
  description = "Value of the google._domainkey TXT record from Google Workspace admin (Apps > Gmail > Authenticate email). Empty: not published."
  type        = string
  default     = ""
}

variable "dmarc_report_email" {
  description = "Where DMARC aggregate reports go. Empty: no reports."
  type        = string
  default     = ""
}
