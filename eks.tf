locals {
  worker_node_groups = [
    for _, config in var.workers : {
      for az, subnet in zipmap(module.vpc.azs, module.vpc.private_subnets) : replace("${config.instance_type}-${az}", ".", "_") => {
        name          = replace("${config.instance_type}-${az}", ".", "_")
        ami_type      = try(config.ami_type, "AL2023_x86_64_STANDARD")
        instance_types = [config.instance_type]
        min_size      = try(config.min_size, 0)
        desired_size = try(config.desired_size, config.min_size, 0)
        max_size      = try(config.max_size, 5)
        subnet_ids    = [subnet]
        labels        = {
          "v1.k8s.vessl.ai/managed"           = "true",
          "v1.k8s.vessl.ai/aws-instance-type" = config.instance_type,
        }
        tags          = merge(
          local.tags,
          {
            "k8s.io/cluster-autoscaler/enabled" = "true",
            "k8s.io/cluster-autoscaler/${var.stack_name}" = "owned",
          }
        )
      }
    }
  ]
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name = var.stack_name
  cluster_version = "1.32"

  cluster_addons = {
    aws-ebs-csi-driver = {}
  }

  cluster_endpoint_public_access = true

  enable_efa_support = true
  enable_irsa = true

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  cluster_endpoint_private_access = true

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

  eks_managed_node_groups = merge(
    {
      system = {
        name = "system"
        ami_type = "AL2023_x86_64_STANDARD"
        instance_types = ["m6i.large"]
        min_size = 1
        max_size = 5
        subnet_ids = module.vpc.public_subnets
        labels = {
          "v1.k8s.vessl.ai/managed" = "true",
          "v1.k8s.vessl.ai/dedicated" = "manager",
        }
        vpc_security_group_ids = [aws_security_group.system_nodeport_public.id]
        tags = merge(
          local.tags,
          {
            "k8s.io/cluster-autoscaler/enabled" = "true",
            "k8s.io/cluster-autoscaler/${var.stack_name}" = "owned",
          }
        )
      },
    },
    local.worker_node_groups...
  )
  tags = local.tags
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}