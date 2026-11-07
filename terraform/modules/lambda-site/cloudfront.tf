locals {
  origin_id = "lambda-${var.name}"

  # AWS managed policies.
  cache_policy_caching_disabled             = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  origin_request_all_viewer_except_host     = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  response_headers_security_headers_managed = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  response_headers_cors_and_security        = "e61eb60c-9c35-4d20-a928-2b84e02af89c"
}

# Pages: cached for page_cache_seconds even though the app sends max-age=0;
# deploys clear the cache.
resource "aws_cloudfront_cache_policy" "pages" {
  name        = "${var.name}-pages"
  min_ttl     = var.page_cache_seconds
  default_ttl = var.page_cache_seconds
  max_ttl     = var.page_cache_seconds

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_cache_policy" "static" {
  name        = "${var.name}-static"
  min_ttl     = 86400
  default_ttl = 86400
  max_ttl     = 86400

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "site" {
  count = local.enabled ? 1 : 0

  comment         = var.domain_names[0]
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_100"

  # Hostnames are attached at cut-over; until then test on the
  # *.cloudfront.net address.
  aliases = var.serve_dns ? var.domain_names : []

  origin {
    origin_id   = local.origin_id
    domain_name = local.function_url_host

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = var.timeout_seconds
    }
  }

  default_cache_behavior {
    target_origin_id         = local.origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.pages.id
    origin_request_policy_id = local.origin_request_all_viewer_except_host
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.uncached_paths

    content {
      path_pattern             = ordered_cache_behavior.value
      target_origin_id         = local.origin_id
      viewer_protocol_policy   = "https-only"
      allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      cache_policy_id          = local.cache_policy_caching_disabled
      origin_request_policy_id = local.origin_request_all_viewer_except_host
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.static_paths

    content {
      path_pattern             = ordered_cache_behavior.value
      target_origin_id         = local.origin_id
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      cache_policy_id          = aws_cloudfront_cache_policy.static.id
      origin_request_policy_id = local.origin_request_all_viewer_except_host
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
    cache_policy_id            = aws_cloudfront_cache_policy.pages.id
    origin_request_policy_id   = local.origin_request_all_viewer_except_host
    response_headers_policy_id = local.response_headers_cors_and_security
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
