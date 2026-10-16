# terraform-aws-ses-cloudflare

Turn a Cloudflare-hosted domain into a verified Amazon SES sending domain in a single `apply` —
DKIM, custom MAIL FROM, SPF and DMARC records are written straight into Cloudflare.

> Status: work in progress.

## Features (planned)

- SES domain identity with Easy DKIM
- Custom MAIL FROM domain with MX and SPF
- DMARC with configurable policy and aggregate report address
- Optional least-privilege IAM sender scoped to the identity
- Tested with `terraform test`, works with Terraform and OpenTofu

## License

MIT

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
