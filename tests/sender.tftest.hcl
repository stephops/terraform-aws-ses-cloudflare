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
      tokens = ["tokena", "tokenb", "tokenc"]
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
    condition     = aws_iam_policy.sender[0].name == "ses-send-eu-central-1-example-com"
    error_message = "Default policy name must contain region and domain, IAM names are global."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Resource == ["arn:aws:ses:eu-central-1:123456789012:identity/example.com"]
    error_message = "Policy must be scoped to the identity ARN."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Action == ["ses:SendEmail"]
    error_message = "Only ses:SendEmail by default."
  }

  assert {
    condition     = !contains(keys(jsondecode(aws_iam_policy.sender[0].policy).Statement[0]), "Condition")
    error_message = "No condition without from_addresses."
  }
}

run "sender_policy_restricts_from_addresses" {
  command = apply

  variables {
    sender = {
      policy_name           = "app-mailer"
      from_addresses        = ["noreply@example.com", "*@notifications.example.com"]
      allow_v1_raw_and_smtp = true
    }
  }

  assert {
    condition     = aws_iam_policy.sender[0].name == "app-mailer"
    error_message = "Custom policy name must be used."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Action) == toset(["ses:SendEmail", "ses:SendRawEmail"])
    error_message = "SendRawEmail must be added for v1 API and SMTP."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Condition.StringLike["ses:FromAddress"]) == toset(["noreply@example.com", "*@notifications.example.com"])
    error_message = "From addresses must be enforced via ses:FromAddress."
  }
}

run "sender_policy_includes_configuration_sets" {
  command = apply

  variables {
    sender = {
      configuration_set_arns = ["arn:aws:ses:eu-central-1:123456789012:configuration-set/default"]
    }
  }

  assert {
    condition     = contains(jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Resource, "arn:aws:ses:eu-central-1:123456789012:configuration-set/default")
    error_message = "Configuration set ARNs must be part of the policy resources."
  }
}

run "default_policy_name_fits_iam_limit" {
  command = apply

  variables {
    domain = "a-very-long-label-for-testing-the-iam-name-limit-of-the-module.another-long-label-to-reach-the-limit.example.com"
    sender = {}
  }

  assert {
    condition     = length(aws_iam_policy.sender[0].name) <= 128
    error_message = "Default policy name must not exceed 128 characters."
  }
}

run "sandbox_recipients_covers_all_identities_with_from_condition" {
  command = apply

  variables {
    sender = {
      from_addresses     = ["noreply@example.com"]
      sandbox_recipients = true
    }
  }

  assert {
    condition     = contains(jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Resource, "arn:aws:ses:eu-central-1:123456789012:identity/*")
    error_message = "Sandbox mode must allow all identities of the account as resource."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.sender[0].policy).Statement[0].Condition.StringLike["ses:FromAddress"] == ["noreply@example.com"]
    error_message = "Sandbox mode must keep the from address restriction."
  }
}

run "rejects_sandbox_recipients_without_from_addresses" {
  command = plan

  variables {
    sender = { sandbox_recipients = true }
  }

  expect_failures = [var.sender]
}

run "rejects_invalid_from_address" {
  command = plan

  variables {
    sender = { from_addresses = ["not-an-address"] }
  }

  expect_failures = [var.sender]
}

run "rejects_from_address_outside_domain" {
  command = plan

  variables {
    sender = { from_addresses = ["noreply@evil.org"] }
  }

  expect_failures = [var.sender]
}

run "rejects_uppercase_from_address" {
  command = plan

  variables {
    sender = { from_addresses = ["NoReply@example.com"] }
  }

  expect_failures = [var.sender]
}

run "rejects_invalid_configuration_set_arn" {
  command = plan

  variables {
    sender = { configuration_set_arns = ["default"] }
  }

  expect_failures = [var.sender]
}
