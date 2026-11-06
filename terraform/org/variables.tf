variable "management_account_id" {
  description = "The organisation's management account, where this layer runs."
  type        = string
  default     = "244971309341"
}

variable "web_account_email" {
  description = "Root email for the web account. Must be unique across AWS."
  type        = string
}

variable "sso_user_name" {
  description = "IAM Identity Center user given admin on the member accounts."
  type        = string
  default     = "mike"
}

variable "budget_email" {
  description = "Where budget alerts go."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly spend across the whole organisation that triggers an alert."
  type        = number
  default     = 10
}

variable "allowed_regions" {
  description = "Regions member accounts may use. us-east-1 is needed for CloudFront certificates."
  type        = list(string)
  default     = ["eu-west-2", "eu-west-1", "us-east-1"]
}
