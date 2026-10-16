.PHONY: fmt validate test test-integration

fmt:
	terraform fmt -recursive

validate:
	terraform init -backend=false -input=false >/dev/null
	terraform validate
	@for e in examples/*/; do \
		(cd $$e && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; \
	done

test: validate
	terraform test

# Creates real resources in AWS and Cloudflare and destroys them afterwards.
test-integration: validate
	@test -n "$$TF_VAR_domain" || (echo "TF_VAR_domain is not set" && exit 1)
	@test -n "$$TF_VAR_cloudflare_zone_id" || (echo "TF_VAR_cloudflare_zone_id is not set" && exit 1)
	@test -n "$$CLOUDFLARE_API_TOKEN" || (echo "CLOUDFLARE_API_TOKEN is not set" && exit 1)
	@test -n "$$AWS_REGION" || (echo "AWS_REGION is not set" && exit 1)
	terraform test -test-directory=tests/integration -verbose