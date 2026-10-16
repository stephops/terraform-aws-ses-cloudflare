mock_provider "aws" {}
mock_provider "cloudflare" {}

variables {
  domain             = "example.com"
  cloudflare_zone_id = "0123456789abcdef0123456789abcdef"
}

override_resource {
  target = aws_sesv2_email_identity.this
  values = {
    arn = "arn:aws:ses:eu-central-1:123456789012:identity/example.com"
    dkim_signing_attributes = {
      next_signing_key_length = "RSA_2048_BIT"
      tokens                  = ["tokena", "tokenb", "tokenc"]
    }
  }
}

override_data {
  target = data.aws_region.current
  values = {
    region = "eu-central-1"
  }
}
run "no_sender_policy_by_default" {
  command = apply

  assert {
    condition     = length(aws_iam_policy.sender) == 0 && output.sender_policy_arn == null
    error_message = "Sender policy must be opt-in."
  }
}

run "sender_policy_scoped_to_identity" {
  command = apply

  variables {
    sender = {}
  }

  assert {
    condition     = aws_iam_policy.sender[0].name == "ses-send-example-com"
    error_message = "Default policy name must be derived from the domain."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Resource == "arn:aws:ses:eu-central-1:123456789012:identity/example.com"
    error_message = "Policy must be scoped to the identity ARN."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Action) == toset(["ses:SendEmail", "ses:SendRawEmail"])
    error_message = "Policy must allow SendEmail and SendRawEmail by default."
  }
}

run "sender_policy_restricts_from_addresses" {
  command = apply

  variables {
    sender = {
      policy_name    = "app-mailer"
      from_addresses = ["noreply@example.com", "*@notifications.example.com"]
      allow_send_raw = false
    }
  }

  assert {
    condition     = aws_iam_policy.sender[0].name == "app-mailer"
    error_message = "Custom policy name must be used."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Action == ["ses:SendEmail"]
    error_message = "SendRawEmail must be excluded when allow_send_raw is false."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Condition.StringLike["ses:FromAddress"]) == toset(["noreply@example.com", "*@notifications.example.com"])
    error_message = "From addresses must be enforced via ses:FromAddress."
  }
}

run "rejects_invalid_from_address" {
  command = plan

  variables {
    sender = { from_addresses = ["not-an-address"] }
  }

  expect_failures = [var.sender]
}
