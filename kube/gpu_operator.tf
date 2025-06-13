locals {
  gpu_operator_helm_values = {
    driver = {
      enabled = false
    }
    operator = {
      cleanupCRD = true
    }
  }
}

resource "helm_release" "gpu_operator" {
  repository = "https://nvidia.github.io/gpu-operator"
  chart      = "gpu-operator"
  name       = "gpu-operator"
  namespace  = "kube-system"
  create_namespace = true
  version    = "1.10.0"
  values     = [yamlencode(local.gpu_operator_helm_values)]
}