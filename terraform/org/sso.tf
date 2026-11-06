# Gives the SSO user the existing AdministratorAccess permission set on the
# web account, so it appears in the SSO portal and `aws sso` profiles.

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

data "aws_ssoadmin_permission_set" "admin" {
  instance_arn = local.sso_instance_arn
  name         = "AdministratorAccess"
}

data "aws_identitystore_user" "me" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.sso_user_name
    }
  }
}

resource "aws_ssoadmin_account_assignment" "web_admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = data.aws_ssoadmin_permission_set.admin.arn
  principal_type     = "USER"
  principal_id       = data.aws_identitystore_user.me.user_id
  target_type        = "AWS_ACCOUNT"
  target_id          = aws_organizations_account.web.id
}
