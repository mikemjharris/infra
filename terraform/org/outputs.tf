output "web_account_id" {
  description = "Use this as sso_account_id for the web profile in ~/.aws/config."
  value       = aws_organizations_account.web.id
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}
