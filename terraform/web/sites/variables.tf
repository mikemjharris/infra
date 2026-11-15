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
