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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  backend "s3" {
    bucket       = "mikemjharris-tfstate-702167621683"
    key          = "web/sites/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}

locals {
  tags = {
    ManagedBy = "terraform"
    Repo      = "mikemjharris/infra"
    Layer     = "web/sites"
  }
}

provider "aws" {
  region              = "eu-west-2"
  allowed_account_ids = [var.web_account_id]

  default_tags {
    tags = local.tags
  }
}

# CloudFront certificates must be in us-east-1.
provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.web_account_id]

  default_tags {
    tags = local.tags
  }
}
