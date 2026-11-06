variable "name" {
  description = "Short name for the site, used in resource names (e.g. www)."
  type        = string
}

variable "domain_names" {
  description = "Hostnames served. The first is canonical; requests for the others get a 301 to it."
  type        = list(string)
}

variable "zone_id" {
  description = "Route 53 zone for certificate validation and the site's records."
  type        = string
}

variable "bucket_name" {
  type = string
}

variable "serve_dns" {
  description = <<-EOT
    Point the hostnames at CloudFront. Leave false while the old server still
    owns them (their records live in web/dns); test on the CloudFront address,
    then remove them from web/dns and set this true in the same change.
  EOT
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "owner/repo whose GitHub Actions may deploy content to this site. Empty: no deploy role."
  type        = string
  default     = ""
}

variable "github_branch" {
  type    = string
  default = "master"
}

variable "github_oidc_provider_arn" {
  type    = string
  default = ""
}
