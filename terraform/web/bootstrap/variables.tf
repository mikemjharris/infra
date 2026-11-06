variable "web_account_id" {
  description = "The web account (created by terraform/org)."
  type        = string
  default     = "702167621683"
}

variable "github_owner" {
  type    = string
  default = "mikemjharris"
}

variable "infra_repo" {
  description = "Repo whose GitHub Actions run Terraform for the web layers."
  type        = string
  default     = "infra"
}
