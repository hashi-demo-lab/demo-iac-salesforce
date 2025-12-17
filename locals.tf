# Local values and computed expressions
# Feature: EC2 Infrastructure with ALB and Nginx

locals {
  # Subnet selection: First 2 subnets from different AZs
  # Reference: FR-002 (Multi-AZ deployment)
  selected_subnets = slice(data.aws_subnets.default.ids, 0, 2)

  # Instance configuration map for for_each deployment
  # Reference: FR-003 (EC2 instance deployment)
  instances = {
    "az-a" = {
      subnet_id = local.selected_subnets[0]
    }
    "az-b" = {
      subnet_id = local.selected_subnets[1]
    }
  }

  # Common resource tags for cost allocation and management
  # Applied to all resources via provider default_tags and module tags
  common_tags = {
    Application = "ec2-alb-nginx"
    Environment = var.environment
    ManagedBy   = "terraform"
    Feature     = "ec2-alb-nginx"
    Description = "Highly available static web infrastructure"
    Repository  = "ec2workspace"
  }
}
