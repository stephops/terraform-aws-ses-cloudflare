terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0, < 6.0"
    }
  }
}

variable "domain" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

provider "aws" {}

provider "cloudflare" {}

module "ses" {
  source = "../.."

  domain             = var.domain
  cloudflare_zone_id = var.cloudflare_zone_id
  dns_ttl            = 300

  dmarc = {
    policy = "none"
    rua    = ["dmarc@${var.domain}"]
  }

  sender = {
    from_addresses     = ["noreply@${var.domain}"]
    sandbox_recipients = true
  }
}
