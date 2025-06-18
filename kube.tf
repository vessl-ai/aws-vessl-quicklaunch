module "kube" {
  depends_on = [module.eks, module.vpc, aws_acm_certificate.cert]
  source     = "./kube"

  agent_access_token                    = var.agent_access_token
  stack_name                            = var.stack_name
  cluster_domain_name                   = var.cluster_domain_name
  aws_region                            = var.aws_region
  workers                               = var.workers
  vpc_id                                = module.vpc.vpc_id
  cluster_autoscaler_role_arn           = aws_iam_role.cluster_autoscaler_role.arn
  external_dns_role_arn                 = aws_iam_role.external_dns_role.arn
  aws_load_balancer_controller_role_arn = aws_iam_role.lb_controller_role.arn
  acm_arn                               = aws_acm_certificate.cert.arn
  public_subnet_ids                     = module.vpc.public_subnets

  providers = {
    helm       = helm.eks
    kubernetes = kubernetes.eks
    aws        = aws
  }
}

resource "null_resource" "load_balancer_ssl_annotation" {
  depends_on = [
    aws_route53_record.validation,
    module.kube
  ]

  provisioner "local-exec" {
    command = <<EOF
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.stack_name}

      kubectl annotate service ingress-nginx-controller \
        "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"="${aws_acm_certificate.cert.arn}" \
        "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"="443" \
        --overwrite \
        -n kube-system
    EOF
  }
}
