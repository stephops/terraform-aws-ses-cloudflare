variable "domain" {
  description = "Domain to verify as SES sending identity, e.g. example.com or notifications.example.com."
  type        = string

  validation {
    condition     = length(var.domain) <= 253 && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+([a-z]{2,63}|xn--[a-z0-9-]{1,59})$", var.domain))
    error_message = "domain must be a lowercase fully qualified domain name without trailing dot, at most 253 characters."
  }
}

variable "cloudflare_zone_id" {
  description = "ID of the Cloudflare zone that hosts the DNS records for the domain."
  type        = string

  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_zone_id))
    error_message = "cloudflare_zone_id must be a 32-character hex string."
  }
}

variable "dkim_key_length" {
  description = "Key length for Easy DKIM: RSA_2048_BIT or RSA_1024_BIT."
  type        = string
  default     = "RSA_2048_BIT"

  validation {
    condition     = contains(["RSA_2048_BIT", "RSA_1024_BIT"], var.dkim_key_length)
    error_message = "dkim_key_length must be RSA_2048_BIT or RSA_1024_BIT."
  }
}

variable "mail_from_subdomain" {
  description = "Subdomain used as custom MAIL FROM domain (<subdomain>.<domain>). Set to null to use the SES default."
  type        = string
  default     = "bounce"

  validation {
    condition     = var.mail_from_subdomain == null || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.mail_from_subdomain))
    error_message = "mail_from_subdomain must be a single DNS label or null."
  }
}

variable "mail_from_behavior_on_mx_failure" {
  description = "What SES does if the MAIL FROM MX record cannot be found: USE_DEFAULT_VALUE or REJECT_MESSAGE."
  type        = string
  default     = "USE_DEFAULT_VALUE"

  validation {
    condition     = contains(["USE_DEFAULT_VALUE", "REJECT_MESSAGE"], var.mail_from_behavior_on_mx_failure)
    error_message = "mail_from_behavior_on_mx_failure must be USE_DEFAULT_VALUE or REJECT_MESSAGE."
  }
}

variable "dmarc" {
  description = "DMARC record to publish at _dmarc.<domain>. Off by default. Only enable it if no other DMARC record exists for that name: two records invalidate both."
  type = object({
    policy           = optional(string, "none")
    subdomain_policy = optional(string)
    percentage       = optional(number, 100)
    rua              = optional(list(string), [])
    alignment_dkim   = optional(string, "r")
    alignment_spf    = optional(string, "r")
  })
  default = null

  validation {
    condition     = var.dmarc == null || contains(["none", "quarantine", "reject"], try(var.dmarc.policy, "none"))
    error_message = "dmarc.policy must be none, quarantine or reject."
  }

  validation {
    condition     = var.dmarc == null || try(var.dmarc.subdomain_policy, null) == null || contains(["none", "quarantine", "reject"], try(var.dmarc.subdomain_policy, "none"))
    error_message = "dmarc.subdomain_policy must be none, quarantine, reject or null."
  }

  validation {
    condition     = var.dmarc == null || (try(var.dmarc.percentage, 100) >= 0 && try(var.dmarc.percentage, 100) <= 100 && floor(try(var.dmarc.percentage, 100)) == try(var.dmarc.percentage, 100))
    error_message = "dmarc.percentage must be a whole number between 0 and 100."
  }

  validation {
    condition     = var.dmarc == null || alltrue([for a in try(var.dmarc.rua, []) : !startswith(lower(a), "mailto:") && can(regex("^[^@:\\s]+@[^@\\s]+\\.[^@\\s]+$", a))])
    error_message = "dmarc.rua must contain plain e-mail addresses (without mailto:)."
  }

  validation {
    condition     = var.dmarc == null || alltrue([for a in [try(var.dmarc.alignment_dkim, "r"), try(var.dmarc.alignment_spf, "r")] : contains(["r", "s"], a)])
    error_message = "dmarc.alignment_dkim and dmarc.alignment_spf must be r (relaxed) or s (strict)."
  }
}

variable "sender" {
  description = "Optional IAM policy that allows sending only from this identity. Attach it to your own role or user. Set to null to skip."
  type = object({
    policy_name            = optional(string)
    from_addresses         = optional(list(string), [])
    configuration_set_arns = optional(list(string), [])
    allow_v1_raw_and_smtp  = optional(bool, false)
    sandbox_recipients     = optional(bool, false)
  })
  default = null

  validation {
    condition     = var.sender == null || !try(var.sender.sandbox_recipients, false) || length(try(var.sender.from_addresses, [])) > 0
    error_message = "sender.sandbox_recipients requires sender.from_addresses, otherwise the policy would allow sending as any identity."
  }

  validation {
    condition = var.sender == null || alltrue([
      for a in try(var.sender.from_addresses, []) :
      a == lower(a) && can(regex("^[^@\\s]+@[^@\\s]+$", a)) && (endswith(a, "@${var.domain}") || endswith(a, ".${var.domain}"))
    ])
    error_message = "sender.from_addresses must be lowercase addresses within the domain or its subdomains, e.g. noreply@<domain> or *@<domain>."
  }

  validation {
    condition     = var.sender == null || alltrue([for a in try(var.sender.configuration_set_arns, []) : can(regex("^arn:aws[a-z-]*:ses:[a-z0-9-]+:[0-9]{12}:configuration-set/.+$", a))])
    error_message = "sender.configuration_set_arns must be SES configuration set ARNs."
  }

  validation {
    condition     = var.sender == null || try(var.sender.policy_name, null) == null || length(try(var.sender.policy_name, "")) <= 128
    error_message = "sender.policy_name must be at most 128 characters."
  }
}

variable "dns_ttl" {
  description = "TTL in seconds for all DNS records. 1 means automatic in Cloudflare."
  type        = number
  default     = 3600

  validation {
    condition     = var.dns_ttl == 1 || (var.dns_ttl >= 60 && var.dns_ttl <= 86400)
    error_message = "dns_ttl must be 1 (automatic) or between 60 and 86400."
  }
}

variable "tags" {
  description = "Tags applied to all AWS resources that support them."
  type        = map(string)
  default     = {}
}
