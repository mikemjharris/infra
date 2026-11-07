# Response headers for every site's /version.json, which the dashboard on www
# reads from the browser. AWS's managed CORS policies allow no request headers,
# and CloudFront then leaves Access-Control-Allow-Origin off whenever a request
# carries any beyond the basics, which browsers always do (sec-fetch-*,
# sec-ch-ua, cache-control). This allows them all. The security headers match
# AWS's managed SecurityHeadersPolicy, used for everything else.
resource "aws_cloudfront_response_headers_policy" "version_json" {
  name    = "version-json-cors"
  comment = "CORS for version.json, read by www.${var.domain}/dashboard/"

  cors_config {
    access_control_allow_credentials = false
    origin_override                  = false
    access_control_max_age_sec       = 86400

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }
  }

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = false
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = false
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      override                   = false
    }

    xss_protection {
      protection = true
      mode_block = true
      override   = false
    }
  }
}
