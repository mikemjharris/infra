variable "web_account_id" {
  type    = string
  default = "702167621683"
}

variable "domain" {
  type    = string
  default = "mikemjharris.com"
}

variable "personal_github_repo" {
  description = "owner/repo whose GitHub Actions deploy personal.mikemjharris.com."
  type        = string
  default     = "mikemjharris/personal"
}

variable "personal_github_subject" {
  description = "Immutable OIDC subject prefix of personal_github_repo (owner and repo ids from the GitHub API)."
  type        = string
  default     = "repo:mikemjharris@1722189/personal@1458813339"
}
