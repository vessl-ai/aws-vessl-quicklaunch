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

variable "gpu_instance_type" {
  description = ""
  type        = string
}

variable "gpu_pool_min_size_per_az" {
  description = ""
  type        = number
  default     = 0
}
variable "gpu_pool_max_size_per_az" {
  description = ""
  type        = number
  default     = 5
}

variable "cpu_instance_type" {
  description = ""
  type        = string
  default     = "m6i.large"
}

variable "cpu_pool_min_size_per_az" {
  description = ""
  type        = number
  default     = 0
}

variable "cpu_pool_max_size_per_az" {
  description = ""
  type        = number
  default     = 5
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
