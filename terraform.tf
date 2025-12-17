# Terraform version constraints and required providers
# Feature: EC2 Infrastructure with ALB and Nginx
# Reference: FR-001 (Infrastructure Requirements)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.19.0"
    }
  }

  # HCP Terraform backend configuration for remote execution
  cloud {
    organization = "hashi-demos-apj"
    workspaces {
      name = "sandbox_ec2workspace"
    }
  }
}
