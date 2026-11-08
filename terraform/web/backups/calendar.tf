# Read-only iCal feed of the Vaillant heating schedule (mikemjharris/homeassistant, calendar-feed.sh),
# for Google Calendar to subscribe to. Google fetches it from its own servers, so it has to be public.
#
# Objects can be read by anyone who knows their name, but the bucket can't be listed. The server picks
# a random name for the feed, so the URL works like a secret link. It only shows heating times.
#
# The server uploads with its own long-lived access key, separate from the backup key. It can only
# write calendar/*, so a stolen key can change the feed but nothing else. The key is created by hand
# with the AWS CLI, so its secret never lands in Terraform state.

locals {
  calendar_prefix = "calendar/"
}

resource "aws_s3_bucket" "calendar" {
  bucket = "mikemjharris-calendar-${var.web_account_id}"
}

resource "aws_s3_bucket_ownership_controls" "calendar" {
  bucket = aws_s3_bucket.calendar.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Public access only through the bucket policy below, never ACLs.
resource "aws_s3_bucket_public_access_block" "calendar" {
  bucket = aws_s3_bucket.calendar.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "calendar_bucket" {
  statement {
    sid       = "PublicReadFeed"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.calendar.arn}/${local.calendar_prefix}*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "calendar" {
  bucket = aws_s3_bucket.calendar.id
  policy = data.aws_iam_policy_document.calendar_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.calendar]
}

resource "aws_iam_user" "homeassistant_calendar" {
  name = "homeassistant-calendar"
}

data "aws_iam_policy_document" "homeassistant_calendar" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.calendar.arn}/${local.calendar_prefix}*"]
  }
}

resource "aws_iam_user_policy" "homeassistant_calendar" {
  name   = "upload-calendar"
  user   = aws_iam_user.homeassistant_calendar.name
  policy = data.aws_iam_policy_document.homeassistant_calendar.json
}

output "calendar_bucket" {
  value = aws_s3_bucket.calendar.bucket
}
