resource "aws_acm_certificate" "cert" {
  domain_name       = "*.${var.cluster_domain_name}"
  validation_method = "DNS"

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [module.vpc]
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id

  depends_on = [aws_acm_certificate.cert]
}


