output "domain" {
  description = "The SES sending domain."
  value       = var.domain
}

output "identity_arn" {
  description = "ARN of the SES domain identity."
  value       = aws_sesv2_email_identity.this.arn
}

output "dkim_tokens" {
  description = "Easy DKIM tokens published as CNAME records."
  value       = local.dkim_tokens
}

output "dkim_record_names" {
  description = "Fully qualified names of the DKIM CNAME records in Cloudflare."
  value       = cloudflare_dns_record.dkim[*].name
}

output "mail_from_domain" {
  description = "The custom MAIL FROM domain, or null if the SES default is used."
  value       = local.mail_from_domain
}
