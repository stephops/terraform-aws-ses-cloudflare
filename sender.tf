locals {
  create_sender      = var.sender != null
  sender_policy_name = local.create_sender ? coalesce(var.sender.policy_name, "ses-send-${replace(var.domain, ".", "-")}") : null
  sender_actions     = local.create_sender ? (var.sender.allow_send_raw ? ["ses:SendEmail", "ses:SendRawEmail"] : ["ses:SendEmail"]) : []

  sender_statement = local.create_sender ? merge(
    {
      Sid      = "SendFromIdentity"
      Effect   = "Allow"
      Action   = local.sender_actions
      Resource = aws_sesv2_email_identity.this.arn
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
  description = "Allows sending e-mail only from the SES identity ${var.domain}."
  policy      = local.sender_policy_json
  tags        = var.tags
}
