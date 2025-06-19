variable "agent_access_token" {
  description = "Access token for Vessl agent"
  type        = string
}

variable "cluster_arn" {
  description = "EKS Cluster ID"
  type        = string
}

variable "stack_name" {
  description = "The name of the Terraform stack"
  type        = string
}

variable "cluster_domain_name" {
  description = "The domain name for the Kubernetes cluster"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "workers" {
  description = <<EOT
    Map of CPU worker instance types and their configurations
    (Note: a node group will be created corresponding to each entry in this map and each subnet within the VPC)
  EOT
  type        = any
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed"
  type        = string
}

variable "cluster_autoscaler_role_arn" {
  description = "ARN of the IAM role for the cluster autoscaler"
  type        = string
}


variable "external_dns_role_arn" {
  description = "ARN of the IAM role for external DNS"
  type        = string
}

variable "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for the load balancer controller"
  type        = string
}

variable "acm_arn" {
  description = "ARN of the ACM certificate for the cluster domain"
  type        = string
}


variable "public_subnet_ids" {
  description = "List of public subnet IDs for the load balancer"
  type        = list(string)
}
