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

variable "github_branches" {
  description = "Branches of github_repo whose GitHub Actions may deploy."
  type        = list(string)
  default     = ["main"]
}

variable "github_oidc_provider_arn" {
  type    = string
  default = ""
}

variable "not_found_page" {
  description = "Path of the page shown for missing files, e.g. /404.html. Empty: S3's own error."
  type        = string
  default     = ""
}

variable "subdomain_cname" {
  description = <<-EOT
    Use a CNAME for non-apex names (only to keep an existing one, as www has);
    otherwise A/AAAA aliases, which can replace an existing A record in place.
  EOT
  type        = bool
  default     = false
}

variable "api_domain_name" {
  description = "Host of an HTTPS backend (e.g. a Lambda function URL) served at api_path_pattern. Empty: none."
  type        = string
  default     = ""
}

variable "api_path_pattern" {
  type    = string
  default = "/api/*"
}

variable "api_origin_verify_secret" {
  description = "Sent to the backend as x-origin-verify, so it can refuse requests that skip CloudFront."
  type        = string
  default     = ""
  sensitive   = true
}
