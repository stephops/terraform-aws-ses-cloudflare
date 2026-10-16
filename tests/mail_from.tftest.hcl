mock_provider "aws" {}
mock_provider "cloudflare" {}

variables {
  domain             = "example.com"
  cloudflare_zone_id = "0123456789abcdef0123456789abcdef"
}

override_resource {
  target = aws_sesv2_email_identity.this
  values = {
    arn = "arn:aws:ses:eu-central-1:123456789012:identity/example.com"
    dkim_signing_attributes = {
      tokens = ["tokena", "tokenb", "tokenc"]
    }
  }
}

override_data {
  target = data.aws_region.current
  values = {
    region = "eu-central-1"
  }
}

run "creates_mail_from_with_mx_and_spf" {
  command = apply

  assert {
    condition     = aws_sesv2_email_identity_mail_from_attributes.this[0].mail_from_domain == "bounce.example.com"
    error_message = "MAIL FROM domain must be <mail_from_subdomain>.<domain>."
  }

  assert {
    condition     = cloudflare_dns_record.mail_from_mx[0].content == "feedback-smtp.eu-central-1.amazonses.com" && cloudflare_dns_record.mail_from_mx[0].priority == 10
    error_message = "MX record must point to the regional SES feedback endpoint with priority 10."
  }

  assert {
    condition     = cloudflare_dns_record.mail_from_spf[0].content == "\"v=spf1 include:amazonses.com ~all\""
    error_message = "SPF record must include amazonses.com."
  }

  assert {
    condition     = aws_sesv2_email_identity_mail_from_attributes.this[0].behavior_on_mx_failure == "USE_DEFAULT_VALUE"
    error_message = "Default MX failure behavior must be USE_DEFAULT_VALUE."
  }
}

run "uses_custom_mail_from_subdomain" {
  command = apply

  variables {
    mail_from_subdomain = "mailfrom"
  }

  assert {
    condition     = cloudflare_dns_record.mail_from_mx[0].name == "mailfrom.example.com"
    error_message = "Custom MAIL FROM subdomain must be used for the MX record."
  }
}

run "skips_mail_from_when_null" {
  command = apply

  variables {
    mail_from_subdomain = null
  }

  assert {
    condition     = length(aws_sesv2_email_identity_mail_from_attributes.this) == 0 && length(cloudflare_dns_record.mail_from_mx) == 0 && length(cloudflare_dns_record.mail_from_spf) == 0
    error_message = "No MAIL FROM resources may be created when mail_from_subdomain is null."
  }

  assert {
    condition     = output.mail_from_domain == null && output.mail_from_mx == null
    error_message = "MAIL FROM outputs must be null when disabled."
  }
}

run "mail_from_on_subdomain_identity" {
  command = apply

  variables {
    domain = "notifications.example.com"
  }

  assert {
    condition     = cloudflare_dns_record.mail_from_mx[0].name == "bounce.notifications.example.com" && cloudflare_dns_record.mail_from_spf[0].name == "bounce.notifications.example.com"
    error_message = "MAIL FROM of a subdomain identity must be below that subdomain."
  }
}

run "records_are_never_proxied" {
  command = apply

  assert {
    condition     = cloudflare_dns_record.mail_from_mx[0].proxied != true && cloudflare_dns_record.mail_from_spf[0].proxied != true
    error_message = "MX and TXT records must not be proxied."
  }
}

run "rejects_multi_label_mail_from" {
  command = plan

  variables {
    mail_from_subdomain = "a.b"
  }

  expect_failures = [var.mail_from_subdomain]
}
