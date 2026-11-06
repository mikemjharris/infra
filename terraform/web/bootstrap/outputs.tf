output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "github_oidc_provider_arn" {
  description = "Used by the sites layer for per-repo deploy roles."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "infra_plan_role_arn" {
  value = aws_iam_role.infra_plan.arn
}

output "infra_apply_role_arn" {
  value = aws_iam_role.infra_apply.arn
}
