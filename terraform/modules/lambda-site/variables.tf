variable "name" {
  description = "Short name for the site, used in resource names (e.g. blog)."
  type        = string
}

variable "domain_names" {
  description = "Hostnames served by the function."
  type        = list(string)
}

variable "zone_id" {
  type = string
}

variable "image_uri" {
  description = <<-EOT
    Container image to run first. Empty creates only the image repository,
    so an image can be pushed before the function exists. After that, deploys
    update the function's image directly; Terraform ignores later changes.
  EOT
  type        = string
  default     = ""
}

variable "memory_mb" {
  type    = number
  default = 1024
}

variable "timeout_seconds" {
  type    = number
  default = 30
}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "page_cache_seconds" {
  description = "How long CloudFront keeps pages. Deploys clear the cache."
  type        = number
  default     = 300
}

variable "static_paths" {
  description = "Path patterns for files that change only on deploy, cached for a day."
  type        = list(string)
  default     = []
}

variable "uncached_paths" {
  description = "Path patterns never cached, with all methods allowed (e.g. /mcp*)."
  type        = list(string)
  default     = []
}

variable "serve_dns" {
  description = "Point the hostnames at CloudFront, overwriting existing A records in place."
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "owner/repo whose GitHub Actions may push images and deploy. Empty: no deploy role."
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
