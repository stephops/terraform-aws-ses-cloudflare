provider "aws" {
  region = "eu-central-1"
}

provider "cloudflare" {}

module "ses_sender" {
  source = "../.."

  domain             = "notifications.example.com"
  cloudflare_zone_id = "0123456789abcdef0123456789abcdef"

  dmarc = {
    policy = "quarantine"
    rua    = ["dmarc-reports@example.com"]
  }

  sender = {
    policy_name    = "app-mailer-ses-send"
    from_addresses = ["noreply@notifications.example.com"]
    allow_send_raw = false
  }

  tags = {
    service = "app-mailer"
  }
}

resource "aws_iam_role" "app" {
  name = "app-mailer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_ses_send" {
  role       = aws_iam_role.app.name
  policy_arn = module.ses_sender.sender_policy_arn
}
