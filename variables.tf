variable "stack_name" {
  description = "The name of the Terraform stack"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "state_bucket_name" {
  description = "The name of the S3 bucket for storing Terraform state files"
  type        = string
}

variable "workers" {
  description = <<EOT
    Map of CPU worker instance types and their configurations
    (Note: a node group will be created corresponding to each entry in this map and each subnet within the VPC)
  EOT
  type = map(object({
    ami_type      = string
    instance_type = string
    min_size      = number
    max_size      = number
  }))
  default = {
    "m6i.large" = {
      ami_type      = "AL2023_x86_64_STANDARD"
      instance_type = "m6i.large"
      min_size      = 0
      desired_size  = 0
      max_size      = 5
    },
    "g4dn.xlarge" = {
      ami_type      = "AL2023_x86_64_NVIDIA"
      instance_type = "g4dn.xlarge"
      min_size      = 0
      desired_size  = 0
      max_size      = 5
    }
  }
}

variable "cluster_domain_name" {
  description = "The domain name for the Kubernetes cluster"
  type        = string
}

variable "agent_access_token" {
  description = "Access token for Vessl agent"
  type        = string
}

variable "admin_role_arn" {
  description = "ARN of the admin role for EKS access"
  type        = string
}
