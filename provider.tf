# AWS Provider configuration
# Feature: EC2 Infrastructure with ALB and Nginx
# Reference: FR-001 (Region: ap-southeast-2)

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "ec2-alb-nginx"
      ManagedBy   = "terraform"
      Workspace   = "sandbox_ec2workspace"
    }
  }
}
