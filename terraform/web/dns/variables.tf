variable "web_account_id" {
  type    = string
  default = "702167621683"
}

variable "domain" {
  type    = string
  default = "mikemjharris.com"
}

variable "google_dkim_record" {
  description = <<-EOT
    Value of the google._domainkey TXT record from Google Workspace admin
    (Apps > Gmail > Authenticate email). It's a public key, published in DNS
    for anyone to read. Empty: not published.
  EOT
  type        = string
  default     = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAocouMze4YhLPyqg7A4TrWTU8F1lOrgSeOCvaUvv8/69zCnd4+q0LAlKgCYEYoB7sGQLqiGpOmchE66ehh6iK5emneknqsrWEjxCv2UG9vPe3BtCOoRtIJj2wdJ6P3yJkfnGD100QnEZ+KtcijGJM6cQAkwJN2xjoIr4Ph2oTar07gbx44TdnPE2la1MbbzbtftBYCRA5M8kQnmMPrJAgsf7CQYksnPuZ/yFdLl2ybUZlLoRRjNQcA3ntdAl64pSm1N8G+vLtPGKaBsE31+F8cl3aR0Swg5xwA/4HF9wVBIXmgAw/11ncMTi/JcqegRIZ1QiHr417oZ8yLCZiN2VYhQIDAQAB"
}

variable "dmarc_report_email" {
  description = "Where DMARC aggregate reports go. Empty: no reports."
  type        = string
  default     = ""
}
