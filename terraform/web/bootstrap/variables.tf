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

# New repos get "immutable" OIDC subjects that include the numeric owner and
# repo IDs (repo:owner@ID/name@ID:...), so a deleted and recreated repo with
# the same name can't assume these roles.
variable "github_owner_id" {
  type    = string
  default = "1722189"
}

variable "infra_repo_id" {
  type    = string
  default = "1448656832"
}
