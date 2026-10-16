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
      next_signing_key_length = "RSA_2048_BIT"
      tokens                  = ["tokena", "tokenb", "tokenc"]
    }
  }
}

override_data {
  target = data.aws_region.current
  values = {
    region = "eu-central-1"
  }
}

run "default_dmarc_is_monitoring_only" {
  command = apply

  assert {
    condition     = cloudflare_dns_record.dmarc[0].name == "_dmarc.example.com"
    error_message = "DMARC record must be published at _dmarc.<domain>."
  }

  assert {
    condition     = output.dmarc_record == "v=DMARC1; p=none; pct=100; adkim=r; aspf=r"
    error_message = "Default DMARC record must be p=none with relaxed alignment."
  }
}

run "full_dmarc_policy" {
  command = apply

  variables {
    dmarc = {
      policy           = "reject"
      subdomain_policy = "quarantine"
      percentage       = 50
      rua              = ["dmarc@example.com", "reports@example.net"]
      alignment_dkim   = "s"
      alignment_spf    = "s"
    }
  }

  assert {
    condition     = output.dmarc_record == "v=DMARC1; p=reject; sp=quarantine; pct=50; adkim=s; aspf=s; rua=mailto:dmarc@example.com,mailto:reports@example.net"
    error_message = "DMARC record must contain all configured tags in order."
  }

  assert {
    condition     = cloudflare_dns_record.dmarc[0].content == "\"${output.dmarc_record}\""
    error_message = "DMARC TXT content must be quoted."
  }
}

run "skips_dmarc_when_null" {
  command = apply

  variables {
    dmarc = null
  }

  assert {
    condition     = length(cloudflare_dns_record.dmarc) == 0 && output.dmarc_record == null
    error_message = "No DMARC record may be managed when dmarc is null."
  }
}

run "rejects_invalid_policy" {
  command = plan

  variables {
    dmarc = { policy = "block" }
  }

  expect_failures = [var.dmarc]
}

run "rejects_mailto_prefix_in_rua" {
  command = plan

  variables {
    dmarc = { rua = ["mailto:dmarc@example.com"] }
  }

  expect_failures = [var.dmarc]
}
