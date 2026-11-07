terraform {
  required_version = ">= 1.10"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # State lives with the web layers'; the AWS profile is only for the backend.
  backend "s3" {
    bucket       = "mikemjharris-tfstate-702167621683"
    key          = "github/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

# Authenticates with GITHUB_TOKEN (bin/terraform fills it from `gh auth token`).
provider "github" {
  owner = "mikemjharris"
}
