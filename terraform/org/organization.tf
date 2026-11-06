# The organisation already exists (created with IAM Identity Center); this
# brings it under Terraform rather than creating it.
import {
  to = aws_organizations_organization.this
  id = "o-j9tfx31cdp"
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # Must list every service already trusted, or Terraform removes it:
  # sso.amazonaws.com is what IAM Identity Center needs.
  aws_service_access_principals = [
    "sso.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "workloads"
  parent_id = local.root_id
}

resource "aws_organizations_account" "web" {
  name      = "web"
  email     = var.web_account_email
  parent_id = aws_organizations_organizational_unit.workloads.id

  # Lets the management account assume admin in the new account if SSO is ever
  # unavailable.
  role_name = "OrganizationAccountAccessRole"

  iam_user_access_to_billing = "ALLOW"

  # Removing this from Terraform must never close the account.
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true
    # AWS doesn't report role_name back after creation.
    ignore_changes = [role_name]
  }
}
