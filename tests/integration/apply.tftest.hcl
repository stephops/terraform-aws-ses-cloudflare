# Real apply against AWS and Cloudflare, destroyed again at the end of the run.
# Not part of the default `terraform test`; run via `make test-integration`.
# Inputs: TF_VAR_domain, TF_VAR_cloudflare_zone_id, AWS_REGION, AWS credentials, CLOUDFLARE_API_TOKEN.

variable "domain" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

provider "aws" {}

provider "cloudflare" {}

run "apply_full_setup" {
  command = apply

  variables {
    domain             = var.domain
    cloudflare_zone_id = var.cloudflare_zone_id
    dns_ttl            = 300

    dmarc = {
      policy = "none"
    }

    sender = {
      policy_name    = "ses-send-integration-test"
      from_addresses = ["noreply@${var.domain}"]
    }

    tags = {
      purpose = "terraform-aws-ses-cloudflare-integration-test"
    }
  }

  assert {
    condition     = startswith(output.identity_arn, "arn:aws:ses:${data.aws_region.current.region}:")
    error_message = "SES identity must be created in the provider region."
  }

  assert {
    condition     = length(output.dkim_tokens) == 3
    error_message = "SES must return three Easy DKIM tokens."
  }

  assert {
    condition     = output.mail_from_mx == "feedback-smtp.${data.aws_region.current.region}.amazonses.com"
    error_message = "MAIL FROM MX must point to the regional feedback endpoint."
  }

  assert {
    condition     = output.sender_policy_arn != null
    error_message = "Sender policy must be created."
  }
}
