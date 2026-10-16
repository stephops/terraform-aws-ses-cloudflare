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

run "creates_domain_identity" {
  command = apply

  assert {
    condition     = aws_sesv2_email_identity.this.email_identity == "example.com"
    error_message = "Identity must be created for the given domain."
  }
}

run "publishes_three_unproxied_dkim_cnames" {
  command = apply

  assert {
    condition     = length(cloudflare_dns_record.dkim) == 3
    error_message = "Exactly three DKIM records are expected."
  }

  assert {
    condition     = alltrue([for r in cloudflare_dns_record.dkim : r.type == "CNAME" && r.proxied == false])
    error_message = "DKIM records must be unproxied CNAMEs, otherwise SES cannot verify them."
  }

  assert {
    condition     = cloudflare_dns_record.dkim[0].name == "tokena._domainkey.example.com"
    error_message = "DKIM record name must be <token>._domainkey.<domain>."
  }

  assert {
    condition     = cloudflare_dns_record.dkim[2].content == "tokenc.dkim.amazonses.com"
    error_message = "DKIM record must point to <token>.dkim.amazonses.com."
  }
}

run "rejects_invalid_domain" {
  command = plan

  variables {
    domain = "Not A Domain"
  }

  expect_failures = [var.domain]
}

run "accepts_punycode_tld" {
  command = plan

  variables {
    domain = "example.xn--p1ai"
  }
}

run "rejects_too_long_domain" {
  command = plan

  variables {
    domain = "abcdefghijabcdefghijabcdefghijabcdefghijabcdefghij.abcdefghijabcdefghijabcdefghijabcdefghijabcdefghij.abcdefghijabcdefghijabcdefghijabcdefghijabcdefghij.abcdefghijabcdefghijabcdefghijabcdefghijabcdefghij.abcdefghijabcdefghijabcdefghijabcdefghijabcdefghij.com"
  }

  expect_failures = [var.domain]
}

run "rejects_invalid_dkim_key_length" {
  command = plan

  variables {
    dkim_key_length = "RSA_4096_BIT"
  }

  expect_failures = [var.dkim_key_length]
}

run "rejects_invalid_ttl" {
  command = plan

  variables {
    dns_ttl = 30
  }

  expect_failures = [var.dns_ttl]
}

run "rejects_invalid_zone_id" {
  command = plan

  variables {
    cloudflare_zone_id = "xyz"
  }

  expect_failures = [var.cloudflare_zone_id]
}

run "uses_custom_ttl" {
  command = apply

  variables {
    dns_ttl = 300
    dmarc   = {}
  }

  assert {
    condition     = alltrue([for r in concat(cloudflare_dns_record.dkim, cloudflare_dns_record.mail_from_mx, cloudflare_dns_record.mail_from_spf, cloudflare_dns_record.dmarc) : r.ttl == 300])
    error_message = "dns_ttl must be applied to every DNS record."
  }
}

run "defaults_to_2048_bit_dkim" {
  command = plan

  assert {
    condition     = aws_sesv2_email_identity.this.dkim_signing_attributes[0].next_signing_key_length == "RSA_2048_BIT"
    error_message = "DKIM keys must default to 2048 bit."
  }
}
