# infra's production environment: the apply jobs run in it, and only main may
# deploy to it. (A named branch rather than "protected branches", which
# predates rulesets.)

import {
  to = github_repository_environment.production
  id = "infra:production"
}

resource "github_repository_environment" "production" {
  repository  = github_repository.repo["infra"].name
  environment = "production"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "production_main" {
  repository     = github_repository.repo["infra"].name
  environment    = github_repository_environment.production.environment
  branch_pattern = "main"
}
