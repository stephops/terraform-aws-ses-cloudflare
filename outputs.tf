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

output "mail_from_mx" {
  description = "MX target of the custom MAIL FROM domain, or null if the SES default is used."
  value       = local.create_mail_from ? cloudflare_dns_record.mail_from_mx[0].content : null
}

output "dmarc_record" {
  description = "The published DMARC record value, or null if DMARC is not managed by this module."
  value       = local.dmarc_record
}

output "sender_policy_arn" {
  description = "ARN of the IAM sender policy, or null if not created."
  value       = local.create_sender ? aws_iam_policy.sender[0].arn : null
}

output "sender_policy_json" {
  description = "JSON of the IAM sender policy, e.g. to embed it inline elsewhere; null if not created."
  value       = local.sender_policy_json
}
