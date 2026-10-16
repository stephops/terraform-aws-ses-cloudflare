provider "aws" {
  region = "eu-central-1"
}

provider "cloudflare" {}

module "ses_sender" {
  source = "../.."

  domain             = "example.com"
  cloudflare_zone_id = "0123456789abcdef0123456789abcdef"

  dmarc = {
    policy = "quarantine"
    rua    = ["dmarc-reports@example.com"]
  }
}
