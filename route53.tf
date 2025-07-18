resource "aws_route53_zone" "primary" {
  name          = var.cluster_domain_name
  comment       = "Primary Route 53 zone for ${var.cluster_domain_name}"
  tags          = local.tags
  force_destroy = true

  depends_on = [module.vpc]
}

