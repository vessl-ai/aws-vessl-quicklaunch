resource "helm_release" "cluster_autoscaler" {
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.46.6"

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = var.stack_name
      }
      awsRegion = var.aws_region
      rbac = {
        create = true
        serviceAccount = {
          create = true
          name = "cluster-autoscaler"
          annotations = {
            "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_role_arn
          }
        }
      }
      nodeSelector = local.node_selector
    })
  ]
}