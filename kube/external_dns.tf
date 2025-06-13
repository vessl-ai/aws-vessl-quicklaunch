resource "helm_release" "external_dns" {
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart = "external-dns"
  name = "external-dns"
  namespace = "kube-system"
  version = "1.15.2"
  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      env = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]
      serviceAccount = {
        create = true
        name = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.external_dns_role_arn
        }
      }
      nodeSelector = local.node_selector
    })
  ]
}