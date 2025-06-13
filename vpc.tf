locals {
  tags = {
    Stack = var.stack_name
    CreatedFrom = "vessl.ai terraform quickstart template"
  }
  azs = length(data.aws_availability_zones.available.names) > 3 ? slice(data.aws_availability_zones.available.names, 0, 3) : data.aws_availability_zones.available.names
}
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc-${var.stack_name}"
  cidr = "10.0.0.0/16"

  azs = local.azs

  map_public_ip_on_launch = true

  public_subnets = [for i in range(length(local.azs)) : "10.0.${i + 1}.0/24"]
  private_subnets = [for i in range(length(local.azs)) : "10.0.${i + 101}.0/24"]
  private_subnet_tags = merge(local.tags, {
    "kubernetes.io/role/internal-elb" = "1",
  })
  public_subnet_tags = merge(local.tags, {
    "kubernetes.io/role/elb" = "1",
  })

  enable_nat_gateway = true

  tags = local.tags
}

resource "aws_security_group" "system_nodeport_public" {
  name = "${var.stack_name}-system-nodeport-public"
  description = "Allow inbound nodeport traffics"
  vpc_id = module.vpc.vpc_id
  tags = local.tags
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}