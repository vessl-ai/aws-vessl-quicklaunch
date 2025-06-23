locals {
  cpu_node_group = {
    (var.cpu_instance_type) = {
      ami_type      = "AL2023_x86_64_STANDARD"
      instance_type = var.cpu_instance_type
      min_size      = var.cpu_pool_min_size_per_az
      desired_size  = var.cpu_pool_min_size_per_az
      max_size      = var.cpu_pool_max_size_per_az
    }
  }

  gpu_node_group = {
    (var.gpu_instance_type) = {
      ami_type      = "AL2023_x86_64_NVIDIA"
      instance_type = var.gpu_instance_type
      min_size      = var.gpu_pool_min_size_per_az
      desired_size  = var.gpu_pool_min_size_per_az
      max_size      = var.gpu_pool_max_size_per_az
    }
  }

  workers = {
    for k, v in merge(local.cpu_node_group, local.gpu_node_group) : k => {
      ami_type      = tostring(v.ami_type)
      instance_type = tostring(v.instance_type)
      min_size      = tonumber(v.min_size)
      desired_size  = tonumber(v.desired_size)
      max_size      = tonumber(v.max_size)
    }
  }

  worker_node_groups = merge(
    [
      for _, config in local.workers : {
        for az, subnet in zipmap(module.vpc.azs, module.vpc.private_subnets) :
        replace("${config["instance_type"]}-${az}", ".", "_") => {
          name           = replace("${config["instance_type"]}-${az}", ".", "_")
          ami_type       = try(config["ami_type"], "AL2023_x86_64_STANDARD")
          instance_types = [config["instance_type"]]
          min_size       = try(config["min_size"], 0)
          desired_size   = try(config["desired_size"], config["min_size"], 0)
          max_size       = try(config["max_size"], 5)
          subnet_ids     = [subnet]
          labels = {
            "v1.k8s.vessl.ai/managed"           = "true",
            "v1.k8s.vessl.ai/aws-instance-type" = config["instance_type"],
          }
          tags = merge(
            local.tags,
            {
              "k8s.io/cluster-autoscaler/enabled"                                               = "true",
              "k8s.io/cluster-autoscaler/${var.stack_name}"                                     = "owned",
              "k8s.io/cluster-autoscaler/node-template/label/v1.k8s.vessl.ai/managed"           = "true",
              "k8s.io/cluster-autoscaler/node-template/label/v1.k8s.vessl.ai/aws-instance-type" = config["instance_type"],
              "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage"             = "512Gi"
            },

            length(data.aws_ec2_instance_type.workers[config["instance_type"]]["gpus"]) > 0 ? {
              "k8s.io/cluster-autoscaler/node-template/resources/nvidia.com/gpu" = tostring(tolist(data.aws_ec2_instance_type.workers[config["instance_type"]]["gpus"])[0]["count"])
            } : {}
          )
        }
      }
    ]...
  )
}

data "aws_ec2_instance_type" "workers" {
  for_each      = local.workers
  instance_type = each.value["instance_type"]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.stack_name
  cluster_version = "1.32"

  cluster_endpoint_public_access = true

  enable_efa_support = true
  enable_irsa        = true

  cluster_addons = {
    metrics-server = {}
  }

  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_endpoint_private_access = true

  depends_on = [module.vpc]

  access_entries = {
    admin = {
      principal_arn = var.admin_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_group_defaults = {
    iam_role_arn    = aws_iam_role.eks_nodegroup_role.arn
    create_iam_role = false
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 512
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 125
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
  }

  eks_managed_node_groups = merge(
    {
      system = {
        name           = "system"
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["m6i.large"]
        min_size       = 1
        max_size       = 5
        subnet_ids     = module.vpc.public_subnets
        labels = {
          "v1.k8s.vessl.ai/managed"   = "true",
          "v1.k8s.vessl.ai/dedicated" = "manager",
        }
        vpc_security_group_ids = [aws_security_group.system_nodeport_public.id]
        tags = merge(
          local.tags,
          {
            "k8s.io/cluster-autoscaler/enabled"                                       = "true",
            "k8s.io/cluster-autoscaler/${var.stack_name}"                             = "owned",
            "k8s.io/cluster-autoscaler/node-template/label/v1.k8s.vessl.ai/managed"   = "true",
            "k8s.io/cluster-autoscaler/node-template/label/v1.k8s.vessl.ai/dedicated" = "manager",
            "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage"     = "512Gi"
          }
        )
      },
    },
    local.worker_node_groups
  )
  tags = local.tags
}

resource "aws_eks_addon" "ebs_csi_driver" {
  depends_on = [module.eks]

  addon_name    = "aws-ebs-csi-driver"
  cluster_name  = module.eks.cluster_name
  addon_version = "v1.29.1-eksbuild.1"
}

resource "kubernetes_storage_class_v1" "default_storage_class" {
  depends_on = [aws_eks_addon.ebs_csi_driver]
  provider   = kubernetes.eks

  metadata {
    name = "vessl-ebs"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
}


data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
