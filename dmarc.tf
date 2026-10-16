locals {
  dmarc_tags = var.dmarc == null ? [] : compact([
    "v=DMARC1",
    "p=${var.dmarc.policy}",
    var.dmarc.subdomain_policy == null ? "" : "sp=${var.dmarc.subdomain_policy}",
    "pct=${var.dmarc.percentage}",
    "adkim=${var.dmarc.alignment_dkim}",
    "aspf=${var.dmarc.alignment_spf}",
    length(var.dmarc.rua) == 0 ? "" : "rua=${join(",", [for a in var.dmarc.rua : "mailto:${a}"])}",
  ])

  dmarc_record = var.dmarc == null ? null : join("; ", local.dmarc_tags)
}

resource "cloudflare_dns_record" "dmarc" {
  count = var.dmarc == null ? 0 : 1

  zone_id = var.cloudflare_zone_id
  name    = "_dmarc.${var.domain}"
  type    = "TXT"
  content = "\"${local.dmarc_record}\""
  ttl     = var.dns_ttl
  comment = "DMARC policy for ${var.domain}"
}
