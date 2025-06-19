resource "helm_release" "aws_load_balancer_controller" {
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.13.2"
  wait       = true
  timeout    = 600

  values = [yamlencode(
    {
      clusterName  = var.stack_name
      nodeSelector = local.node_selector
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.aws_load_balancer_controller_role_arn
        }
      }
      vpcId = var.vpc_id
    }
  )]
}
