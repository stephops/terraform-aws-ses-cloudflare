output "domain" {
  description = "The SES sending domain."
  value       = var.domain
}

output "mail_from_domain" {
  description = "The custom MAIL FROM domain, or null if the SES default is used."
  value       = local.mail_from_domain
}
