# Data sources for resource discovery
# Feature: EC2 Infrastructure with ALB and Nginx

# Default VPC discovery
# Reference: FR-001 (Default VPC requirement)
data "aws_vpc" "default" {
  default = true
}

# Default VPC subnets discovery
# Reference: FR-002 (Multi-AZ subnet selection)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Amazon Linux 2023 AMI via SSM Parameter
# Reference: FR-003 (Amazon Linux 2023 requirement)
# SSM parameter provides latest AMI ID automatically
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
