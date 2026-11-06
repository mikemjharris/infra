variable "web_account_id" {
  type    = string
  default = "702167621683"
}

variable "domain" {
  type    = string
  default = "mikemjharris.com"
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
