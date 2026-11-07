# My active repos' settings and the rules on their main branches.
#
# Applied by hand (bin/terraform from this folder), like terraform/org: CI
# would need a GitHub token with admin on every repo, which is more power than
# its roles should hold.

locals {
  # Per repo: description, homepage, and the CI checks that must pass before
  # a pull request can merge into main.
  repos = {
    infra = {
      description = "Terraform for mikemjharris.com on AWS (S3 + CloudFront + Lambda)"
      homepage    = ""
      checks      = ["Terraform plan"]
      # Plans must be made against the current main, so a PR has to be up to
      # date before it merges.
      strict = true
    }
    personal-website = {
      description = "My personal website, www.mikemjharris.com"
      homepage    = "https://www.mikemjharris.com"
      checks      = ["Check"]
      strict      = false
    }
    blog = {
      description = "My blog: Express + Handlebars, server-rendered, on AWS Lambda"
      homepage    = "https://blog.mikemjharris.com"
      checks      = ["Build, test and boot", "Docker image boots"]
      strict      = false
    }
    books = {
      description = "The books I've read, from a Google Sheet"
      homepage    = "https://books.mikemjharris.com"
      checks      = ["build"]
      strict      = false
    }
    threejs-snowman = {
      description = "Three.js snowball fight game"
      homepage    = "https://snowman.mikemjharris.com"
      checks      = ["build"]
      strict      = false
    }
    svg-animation-with-node-server = {
      description = "Animated SVG message"
      homepage    = "https://animated-message.mikemjharris.com"
      checks      = ["build"]
      strict      = false
    }
    config = {
      description = "Config - command line setup etc."
      homepage    = ""
      checks      = ["Install test"]
      strict      = false
    }
    dashboard = {
      description = "What's deployed on each of my sites"
      homepage    = "https://www.mikemjharris.com/dashboard/"
      checks      = ["Check"]
      strict      = false
    }
  }

  # Checks must come from GitHub Actions, not a commit status anyone with
  # write access could post.
  github_actions_app_id = 15368
}

import {
  for_each = local.repos
  to       = github_repository.repo[each.key]
  id       = each.key
}

resource "github_repository" "repo" {
  for_each = local.repos

  name         = each.key
  description  = each.value.description
  homepage_url = each.value.homepage
  visibility   = "public"

  has_issues   = true
  has_wiki     = true
  has_projects = true

  # Rebase only, so main's history is linear and every commit on it was
  # reviewed as it is; "Update branch" rebases too.
  allow_merge_commit     = false
  allow_squash_merge     = false
  allow_rebase_merge     = true
  allow_update_branch    = true
  delete_branch_on_merge = true

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_ruleset" "main" {
  for_each = local.repos

  name        = "main"
  repository  = github_repository.repo[each.key].name
  target      = "branch"
  enforcement = "active"

  # No bypass actors: the rules bind admins too.

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_review_thread_resolution = false
      allowed_merge_methods             = ["rebase"]
    }

    required_status_checks {
      strict_required_status_checks_policy = each.value.strict

      dynamic "required_check" {
        for_each = each.value.checks

        content {
          context        = required_check.value
          integration_id = local.github_actions_app_id
        }
      }
    }
  }
}
