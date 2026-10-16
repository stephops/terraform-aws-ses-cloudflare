#!/usr/bin/env bash
# Applies the module for real, fails if a second plan is not empty, always destroys afterwards.
set -euo pipefail

: "${TF_VAR_domain:?TF_VAR_domain is not set}"
: "${TF_VAR_cloudflare_zone_id:?TF_VAR_cloudflare_zone_id is not set}"
: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is not set}"
: "${AWS_REGION:?AWS_REGION is not set}"

cd "$(dirname "$0")/../tests/idempotency"

cleanup() {
  terraform destroy -auto-approve -input=false >/dev/null || echo "WARNING: destroy failed, clean up manually" >&2
  rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
}
trap cleanup EXIT

terraform init -input=false >/dev/null
terraform apply -auto-approve -input=false

set +e
terraform plan -detailed-exitcode -input=false
rc=$?
set -e

case $rc in
  0) echo "OK: second plan is empty" ;;
  2) echo "FAIL: second plan shows changes, the module is not idempotent" >&2; exit 1 ;;
  *) echo "FAIL: plan error" >&2; exit 1 ;;
esac
