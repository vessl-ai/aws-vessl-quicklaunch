locals {
  node_affinity = {
    requiredDuringSchedulingIgnoredDuringExecution = {
      nodeSelectorTerms = [
        {
          matchExpressions = [
            {
              key      = "v1.k8s.vessl.ai/dedicated"
              operator = "In"
              values   = ["manager"]
            }
          ]
        }
      ]
    }
  }
  node_selector = {
    "v1.k8s.vessl.ai/dedicated" = "manager"
  }
  agent_helm_values = {
    agent = {
      env = "prod"
      apiServer = "https://api.vessl.ai"
      accessToken = var.agent_access_token
      clusterName = var.stack_name
      providerType = "aws"
      image = "quay.io/vessl-ai/cluster-agent:0.6.29"
      containerRuntime = "containerd"
      clusterServiceType = "Ingress"
      ingressEndpoint = var.cluster_domain_name
      region = var.aws_region
      nodeSelector = local.node_selector
      resourceSpecs = {
        for worker, config in var.workers : worker => {
          name = config.instance_type
          processorType = length(data.aws_ec2_instance_type.workers[worker].gpus) > 0 ? "GPU" : "CPU"
          cpuLimit = data.aws_ec2_instance_type.workers[worker].default_vcpus * 0.8
          memoryLimit = "${floor(data.aws_ec2_instance_type.workers[worker].memory_size * 0.8)}Mi"
          gpuLimit = length(data.aws_ec2_instance_type.workers[worker].gpus) > 0 ? tolist(data.aws_ec2_instance_type.workers[worker].gpus)[0].count : null
          gpuType = length(data.aws_ec2_instance_type.workers[worker].gpus) > 0 ? tolist(data.aws_ec2_instance_type.workers[worker].gpus)[0].name : null
          priority = 1
          labels = [
            {
              key = "v1.k8s.vessl.ai/managed"
              value = "true"
            },
            {
              key = "v1.k8s.vessl.ai/aws-instance-type"
              value = config.instance_type
            }
          ]
        }
      }
    }
    local-path-provisioner = {
      enabled = false
    }
    longhorn = {
      enabled = false
    }
    dcgm-exporter = {
      enabled = false
    }
    nvidia-device-plugin = {
      enabled = false
    }
    nfd = {
      enabled = false
    }
    gfd = {
      enabled = false
    }
    image-prepull = {
      enabled = false
    }
    prometheus-remote-write = {
      server = {
        remoteWrite = [
          {
            name = "vessl-remote-write"
            url  = "https://remote-write-gateway.vessl.ai/remote-write"
            authorization = {
              type             = "Token"
              credentials_file = "/etc/secrets/token"
            }
            write_relabel_configs = [
              {
                action = "labeldrop"
                regex  = "feature_node_kubernetes_io_(.+)"
              },
              {
                action = "labeldrop"
                regex  = "label_feature_node_kubernetes_io_(.+)"
              },
              {
                action = "labeldrop"
                regex  = "beta_kubernetes_io_(.+)"
              },
            ]
          }
        ],
      }
    }
  }
}
data "aws_ec2_instance_type" "workers" {
  for_each = var.workers
  instance_type = each.value.instance_type
}
resource "helm_release" "vessl_agent" {
  repository = "https://vessl-ai.github.io/helm-charts"
  chart = "vessl"
  name = "vessl"
  namespace = "vessl"
  create_namespace = true
  version = "0.0.57"
  values = [yamlencode(local.agent_helm_values)]
  timeout = 60 * 60 # 1H
}
