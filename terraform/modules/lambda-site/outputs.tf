output "repository_url" {
  value = aws_ecr_repository.site.repository_url
}

output "function_name" {
  value = try(aws_lambda_function.site[0].function_name, null)
}

output "distribution_id" {
  value = try(aws_cloudfront_distribution.site[0].id, null)
}

output "cloudfront_domain" {
  description = "Test the site here before cut-over."
  value       = try(aws_cloudfront_distribution.site[0].domain_name, null)
}

output "deploy_role_arn" {
  value = try(aws_iam_role.deploy[0].arn, null)
}
