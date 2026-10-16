locals {
  create_sender = var.sender != null

  sender_default_policy_name = substr("ses-send-${data.aws_region.current.region}-${replace(var.domain, ".", "-")}", 0, 128)
  sender_policy_name         = local.create_sender ? coalesce(var.sender.policy_name, local.sender_default_policy_name) : null

  # SES v2 SendEmail also covers raw MIME content; SendRawEmail is only used by the v1 API and SMTP.
  sender_actions = local.create_sender ? (var.sender.allow_v1_raw_and_smtp ? ["ses:SendEmail", "ses:SendRawEmail"] : ["ses:SendEmail"]) : []

  # In the SES sandbox the recipient identity is authorized too, so the policy has to cover all identities of the account.
  sender_sandbox_resources = local.create_sender && try(var.sender.sandbox_recipients, false) ? [replace(aws_sesv2_email_identity.this.arn, "/identity\\/.*$/", "identity/*")] : []

  sender_statement = local.create_sender ? merge(
    {
      Sid      = "SendFromIdentity"
      Effect   = "Allow"
      Action   = local.sender_actions
      Resource = concat([aws_sesv2_email_identity.this.arn], local.sender_sandbox_resources, var.sender.configuration_set_arns)
    },
    length(var.sender.from_addresses) > 0 ? {
      Condition = {
        StringLike = {
          "ses:FromAddress" = var.sender.from_addresses
        }
      }
    } : {}
  ) : null

  sender_policy_json = local.create_sender ? jsonencode({
    Version   = "2012-10-17"
    Statement = [local.sender_statement]
  }) : null
}

resource "aws_iam_policy" "sender" {
  count = local.create_sender ? 1 : 0

  name        = local.sender_policy_name
  description = substr("Allows sending e-mail only from the SES identity ${var.domain}.", 0, 1000)
  policy      = local.sender_policy_json
  tags        = var.tags
}
