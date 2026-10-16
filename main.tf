locals {
  mail_from_domain = var.mail_from_subdomain == null ? null : "${var.mail_from_subdomain}.${var.domain}"
}
