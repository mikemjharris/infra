output "bucket" {
  value = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain" {
  description = "Test the site here before cut-over."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "deploy_role_arn" {
  value = try(aws_iam_role.deploy[0].arn, null)
}
