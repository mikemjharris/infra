terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "mikemjharris-tfstate-702167621683"
    key          = "web/dns/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-2"

  allowed_account_ids = [var.web_account_id]

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = "mikemjharris/infra"
      Layer     = "web/dns"
    }
  }
}
