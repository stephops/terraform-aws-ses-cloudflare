# With IAM sender

SES identity for the subdomain `notifications.example.com` plus an IAM policy that only allows
sending as `noreply@notifications.example.com`. The policy is attached to an ECS task role.

Replace the domain and the zone ID, then run `terraform init` and `terraform apply`.
