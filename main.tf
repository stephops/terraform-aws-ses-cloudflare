locals {
  mail_from_domain = var.mail_from_subdomain == null ? null : "${var.mail_from_subdomain}.${var.domain}"

  # Easy DKIM always issues three tokens; a fixed count keeps the plan known before apply.
  dkim_token_count = 3
  dkim_tokens      = aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens
}

resource "aws_sesv2_email_identity" "this" {
  email_identity = var.domain
  tags           = var.tags

  dkim_signing_attributes {
    next_signing_key_length = var.dkim_key_length
  }
}

resource "cloudflare_dns_record" "dkim" {
  count = local.dkim_token_count

  zone_id = var.cloudflare_zone_id
  name    = "${local.dkim_tokens[count.index]}._domainkey.${var.domain}"
  type    = "CNAME"
  content = "${local.dkim_tokens[count.index]}.dkim.amazonses.com"
  ttl     = var.dns_ttl
  proxied = false
  comment = "SES Easy DKIM for ${var.domain}"
}
