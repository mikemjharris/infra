resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.name}-s3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "viewer_request" {
  name    = "${var.name}-viewer-request"
  runtime = "cloudfront-js-2.0"
  comment = "Redirect non-canonical hosts; serve index.html for directories"
  publish = true
  code = templatefile("${path.module}/viewer-request.js", {
    canonical_host = var.domain_names[0]
    redirect_hosts = jsonencode(slice(var.domain_names, 1, length(var.domain_names)))
  })
}

locals {
  origin_id = "s3-${var.name}"

  # AWS managed policies.
  cache_policy_caching_optimized     = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  response_headers_security_headers  = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  response_headers_cors_and_security = "e61eb60c-9c35-4d20-a928-2b84e02af89c"
}

resource "aws_cloudfront_distribution" "site" {
  comment             = var.domain_names[0]
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  # Hostnames are attached at cut-over; until then test on the
  # *.cloudfront.net address.
  aliases = var.serve_dns ? var.domain_names : []

  origin {
    origin_id                = local.origin_id
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cache_policy_caching_optimized
    response_headers_policy_id = local.response_headers_security_headers

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.viewer_request.arn
    }
  }

  # version.json (commit and deploy time) can be read from any site, so the
  # dashboard on www can show every site's.
  ordered_cache_behavior {
    path_pattern               = "/version.json"
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.cache_policy_caching_optimized
    response_headers_policy_id = local.response_headers_cors_and_security
  }

  dynamic "custom_error_response" {
    for_each = var.not_found_page != "" ? [var.not_found_page] : []

    content {
      error_code            = 404
      response_code         = 404
      response_page_path    = custom_error_response.value
      error_caching_min_ttl = 60
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
