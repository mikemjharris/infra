terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  # The bucket is created by this layer (state.tf). On a fresh setup, comment
  # this out for the first apply, then uncomment and `terraform init -migrate-state`.
  backend "s3" {
    bucket       = "mikemjharris-tfstate-702167621683"
    key          = "web/bootstrap/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-2"

  # Guard against running this layer with credentials for the wrong account.
  allowed_account_ids = [var.web_account_id]

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "mikemjharris/infra"
      Layer     = "web/bootstrap"
    }
  }
}
