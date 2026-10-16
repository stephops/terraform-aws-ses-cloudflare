data "aws_region" "current" {}

locals {
  create_mail_from = local.mail_from_domain != null
}

resource "aws_sesv2_email_identity_mail_from_attributes" "this" {
  count = local.create_mail_from ? 1 : 0

  email_identity         = aws_sesv2_email_identity.this.email_identity
  mail_from_domain       = local.mail_from_domain
  behavior_on_mx_failure = var.mail_from_behavior_on_mx_failure
}

resource "cloudflare_dns_record" "mail_from_mx" {
  count = local.create_mail_from ? 1 : 0

  zone_id  = var.cloudflare_zone_id
  name     = local.mail_from_domain
  type     = "MX"
  content  = "feedback-smtp.${data.aws_region.current.region}.amazonses.com"
  priority = 10
  ttl      = var.dns_ttl
  comment  = substr("SES MAIL FROM for ${var.domain}", 0, 100)
}

resource "cloudflare_dns_record" "mail_from_spf" {
  count = local.create_mail_from ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = local.mail_from_domain
  type    = "TXT"
  content = "\"v=spf1 include:amazonses.com ~all\""
  ttl     = var.dns_ttl
  comment = substr("SES MAIL FROM SPF for ${var.domain}", 0, 100)
}
