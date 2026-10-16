# terraform-aws-ses-cloudflare

Terraform module that makes a Cloudflare-hosted domain ready for sending mail with Amazon SES.

It creates the SES domain identity and writes the DNS records SES needs into the Cloudflare zone:
DKIM and MAIL FROM (MX and SPF). Optionally it publishes a DMARC record and creates an IAM policy
that only allows sending from that identity. Works with Terraform and OpenTofu.

## Usage

```hcl
module "ses_sender" {
  source  = "StephOps/ses-cloudflare/aws"
  version = "~> 0.1.0"

  domain             = "example.com"
  cloudflare_zone_id = "0123456789abcdef0123456789abcdef"

  dmarc = {
    policy = "quarantine"
    rua    = ["dmarc-reports@example.com"]
  }

  sender = {
    from_addresses = ["noreply@example.com"]
  }
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = module.ses_sender.sender_policy_arn
}
```

Two complete examples are in [examples/basic](./examples/basic) and
[examples/with-iam-sender](./examples/with-iam-sender).

## What it does

The identity uses Easy DKIM with 2048-bit keys by default (`dkim_key_length`). The three DKIM
records are CNAMEs and are never proxied, otherwise SES cannot verify them.

MAIL FROM defaults to `bounce.<domain>`. The MX record points to the SES feedback endpoint of the
provider region, the SPF record includes `amazonses.com`. Set `mail_from_subdomain = null` to keep
the SES default. Make sure the name is not used yet: an existing CNAME blocks the MX record, an
existing SPF record would end up as a second one.

DMARC is off by default. A domain must have exactly one DMARC record, a second one makes receivers
ignore both. Set `dmarc = {}` for a record with `p=none`, or configure policy, alignment and report
addresses. Without `rua` no reports are sent, so add an address if you want to see what happens
before moving to `quarantine` or `reject`.

The sender policy is optional. It allows `ses:SendEmail` on the identity, optionally restricted to
certain from addresses via `ses:FromAddress`. If you send with a configuration set, add its ARN to
`configuration_set_arns`. `allow_v1_raw_and_smtp` adds `ses:SendRawEmail`, which is only needed for
the SES v1 API and SMTP. The module does not create IAM users or access keys. Attach the policy to
your own role.

## Things to know

SES verifies the domain on its own schedule. Usually this takes a few minutes, in rare cases up to
72 hours. The module does not wait for it.

New AWS accounts are in the SES sandbox and can only send to verified addresses. Production access
has to be requested per region:
[Request production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html).
In the sandbox SES also checks the permission against the recipient identity, so a policy that is
restricted to the sender identity can be denied there. This goes away with production access.

The identity lives in the region of the AWS provider. For more than one sending region use one
module instance per region. The default policy name contains the region, because IAM names are
global.

If `rua` points to another domain, that domain has to publish an authorization record
(`<your-domain>._report._dmarc.<report-domain>`), otherwise reports are not delivered.

`subdomain_policy` (`sp`) only has an effect on the DMARC record of the organizational domain.
On a subdomain identity receivers ignore it.

The Cloudflare provider reads `CLOUDFLARE_API_TOKEN`. The token needs Zone / DNS / Edit on this zone,
nothing more. The domain has to belong to the zone given in `cloudflare_zone_id`.

## Tests

`make test` runs the unit tests with mocked providers and needs no credentials.

`make test-integration` creates everything for real and destroys it afterwards. It needs AWS
credentials, `AWS_REGION`, `CLOUDFLARE_API_TOKEN`, `TF_VAR_cloudflare_zone_id` and `TF_VAR_domain`.
Use a throwaway subdomain for the latter.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | >= 5.0, < 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0, < 7.0 |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | >= 5.0, < 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy.sender](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_sesv2_email_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sesv2_email_identity) | resource |
| [aws_sesv2_email_identity_mail_from_attributes.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sesv2_email_identity_mail_from_attributes) | resource |
| [cloudflare_dns_record.dkim](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.dmarc](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.mail_from_mx](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.mail_from_spf](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | ID of the Cloudflare zone that hosts the DNS records for the domain. | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | Domain to verify as SES sending identity, e.g. example.com or notifications.example.com. | `string` | n/a | yes |
| <a name="input_dkim_key_length"></a> [dkim\_key\_length](#input\_dkim\_key\_length) | Key length for Easy DKIM: RSA\_2048\_BIT or RSA\_1024\_BIT. | `string` | `"RSA_2048_BIT"` | no |
| <a name="input_dmarc"></a> [dmarc](#input\_dmarc) | DMARC record to publish at \_dmarc.<domain>. Off by default. Only enable it if no other DMARC record exists for that name: two records invalidate both. | <pre>object({<br/>    policy           = optional(string, "none")<br/>    subdomain_policy = optional(string)<br/>    percentage       = optional(number, 100)<br/>    rua              = optional(list(string), [])<br/>    alignment_dkim   = optional(string, "r")<br/>    alignment_spf    = optional(string, "r")<br/>  })</pre> | `null` | no |
| <a name="input_dns_ttl"></a> [dns\_ttl](#input\_dns\_ttl) | TTL in seconds for all DNS records. 1 means automatic in Cloudflare. | `number` | `3600` | no |
| <a name="input_mail_from_behavior_on_mx_failure"></a> [mail\_from\_behavior\_on\_mx\_failure](#input\_mail\_from\_behavior\_on\_mx\_failure) | What SES does if the MAIL FROM MX record cannot be found: USE\_DEFAULT\_VALUE or REJECT\_MESSAGE. | `string` | `"USE_DEFAULT_VALUE"` | no |
| <a name="input_mail_from_subdomain"></a> [mail\_from\_subdomain](#input\_mail\_from\_subdomain) | Subdomain used as custom MAIL FROM domain (<subdomain>.<domain>). Set to null to use the SES default. | `string` | `"bounce"` | no |
| <a name="input_sender"></a> [sender](#input\_sender) | Optional IAM policy that allows sending only from this identity. Attach it to your own role or user. Set to null to skip. | <pre>object({<br/>    policy_name            = optional(string)<br/>    from_addresses         = optional(list(string), [])<br/>    configuration_set_arns = optional(list(string), [])<br/>    allow_v1_raw_and_smtp  = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all AWS resources that support them. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dkim_record_names"></a> [dkim\_record\_names](#output\_dkim\_record\_names) | Fully qualified names of the DKIM CNAME records in Cloudflare. |
| <a name="output_dkim_tokens"></a> [dkim\_tokens](#output\_dkim\_tokens) | Easy DKIM tokens published as CNAME records. |
| <a name="output_dmarc_record"></a> [dmarc\_record](#output\_dmarc\_record) | The published DMARC record value, or null if DMARC is not managed by this module. |
| <a name="output_domain"></a> [domain](#output\_domain) | The SES sending domain. |
| <a name="output_identity_arn"></a> [identity\_arn](#output\_identity\_arn) | ARN of the SES domain identity. |
| <a name="output_mail_from_domain"></a> [mail\_from\_domain](#output\_mail\_from\_domain) | The custom MAIL FROM domain, or null if the SES default is used. |
| <a name="output_mail_from_mx"></a> [mail\_from\_mx](#output\_mail\_from\_mx) | MX target of the custom MAIL FROM domain, or null if the SES default is used. |
| <a name="output_sender_policy_arn"></a> [sender\_policy\_arn](#output\_sender\_policy\_arn) | ARN of the IAM sender policy, or null if not created. |
| <a name="output_sender_policy_json"></a> [sender\_policy\_json](#output\_sender\_policy\_json) | JSON of the IAM sender policy, e.g. to embed it inline elsewhere; null if not created. |
<!-- END_TF_DOCS -->

## Changelog and license

Changes are listed in [CHANGELOG.md](./CHANGELOG.md). MIT license, see [LICENSE](./LICENSE).
