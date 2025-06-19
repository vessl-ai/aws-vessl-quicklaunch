resource "helm_release" "ingress_nginx" {
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  name       = "ingress-nginx"
  namespace  = "kube-system"
  version    = "4.12.1"
  depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns]

  values = [
    yamlencode({
      controller = {
        ingressClassResource = {
          name            = "nginx"
          enabled         = true
          default         = true
          controllerValue = "k8s.io/ingress-nginx"
        }

        service = {
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname"                                      = "*.${var.cluster_domain_name}"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"                  = "tcp"
            "service.beta.kubernetes.io/aws-load-balancer-subnets"                           = join(",", var.public_subnet_ids)
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
            # ingress_nginx 생성 완료 이후, annotation 외부에서 추가 예정
            # "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"                          = var.acm_arn
            # "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"                         = "443"
          }
          targetPorts = {
            https = "80"
          }
          loadBalancerClass = "service.k8s.aws/nlb"
        }
        resources = {
          requests = {
            cpu    = "300m"
            memory = "500Mi"
          }
        }
        config = {
          proxy-body-size     = "1g"
          client-body-timeout = "5m"
        }
        replicaCount = 1
        minAvailable = 1
        autoscaling = {
          enabled                           = true
          minReplicas                       = 1
          maxReplicas                       = 5
          targetCPUUtilizationPercentage    = 50
          targetMemoryUtilizationPercentage = 80
        }
      }
    })
  ]
}

resource "kubernetes_service" "tcp" {
  depends_on = [helm_release.aws_load_balancer_controller, helm_release.external_dns]

  metadata {
    name      = "tcp"
    namespace = "kube-system"
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname"       = "tcp.${var.cluster_domain_name}"
      "external-dns.alpha.kubernetes.io/endpoints-type" = "NodeExternalIP"
    }
  }
  spec {
    cluster_ip = "None"
    selector = {
      "app.kubernetes.io/instance"  = "ingress-nginx"
      "app.kubernetes.io/component" = "controller"
    }
  }
}
