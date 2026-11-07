output "www" {
  value = module.www
}

output "blog" {
  value = module.blog
}

output "books" {
  value = module.books
}

output "snowman" {
  value = module.snowman
}

output "animated_message" {
  value = module.animated_message
}

output "dashboard_deploy_role_arn" {
  value = aws_iam_role.dashboard_deploy.arn
}
