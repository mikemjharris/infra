# Off-site backups for the Home Assistant server (mikemjharris/homeassistant,
# backup.sh). Each backup is encrypted with age on the server before upload;
# the private key isn't on the server or in AWS, so neither can read them.
#
# The server uploads with a long-lived access key (it runs unattended, so SSO
# doesn't fit). The key can only add new objects under homeassistant/: it
# can't read, list, overwrite or delete, so a stolen key can't touch existing
# backups. The key itself is created by hand with the AWS CLI, so its secret
# never lands in Terraform state.

locals {
  backup_prefix = "homeassistant/"
}

resource "aws_s3_bucket" "backups" {
  bucket = "mikemjharris-backups-${var.web_account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Daily backups of a few MB each: keep 90 days.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_iam_user" "homeassistant_backup" {
  name = "homeassistant-backup"
}

data "aws_iam_policy_document" "homeassistant_backup" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.backups.arn}/${local.backup_prefix}*"]

    # Only brand-new objects: S3 refuses the upload if the key exists.
    condition {
      test     = "StringEquals"
      variable = "s3:if-none-match"
      values   = ["*"]
    }
  }
}

resource "aws_iam_user_policy" "homeassistant_backup" {
  name   = "upload-backups"
  user   = aws_iam_user.homeassistant_backup.name
  policy = data.aws_iam_policy_document.homeassistant_backup.json
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}
