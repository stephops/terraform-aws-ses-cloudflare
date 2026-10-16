# Basic

SES identity for `example.com` with DKIM, MAIL FROM `bounce.example.com` and a DMARC record in
quarantine mode. Reports go to `dmarc-reports@example.com`.

Replace the domain and the zone ID, then run `terraform init` and `terraform apply`.
