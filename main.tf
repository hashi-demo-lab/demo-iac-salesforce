# Module declarations for EC2 Infrastructure with ALB and Nginx
# Feature: EC2 Infrastructure with ALB and Nginx
# All modules sourced from HCP Terraform private registry

# =============================================================================
# Security Groups
# =============================================================================

# ALB Security Group
# Reference: FR-004 (Security group for internet-facing ALB)
module "alb_sg" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "5.3.1"

  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  # Ingress: Allow HTTP and HTTPS from internet
  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS from internet"
    }
  ]

  # Egress: Allow HTTP to EC2 instances only
  egress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.ec2_sg.security_group_id
      description              = "HTTP to EC2 instances"
    }
  ]

  tags = local.common_tags
}

# EC2 Security Group
# Reference: FR-005 (Security group for EC2 web servers)
module "ec2_sg" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "5.3.1"

  name        = "ec2-security-group"
  description = "Security group for EC2 web servers"
  vpc_id      = data.aws_vpc.default.id

  # Ingress: Allow HTTP from ALB only
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "HTTP from ALB only"
    }
  ]

  # Egress: Allow HTTP and HTTPS for package downloads
  egress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP for package downloads"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS for package downloads"
    }
  ]

  tags = local.common_tags
}

# =============================================================================
# ACM Certificate
# =============================================================================

# ACM Certificate with DNS validation
# Reference: FR-006 (TLS/SSL certificate for HTTPS)
# Note: ACM certificate disabled for sandbox HTTP-only testing
# Enable for production with valid domain and DNS validation
# module "acm" {
#   source  = "app.terraform.io/hashi-demos-apj/acm/aws"
#   version = "6.1.1"
#
#   domain_name          = var.domain_name
#   validation_method    = "DNS"
#   validate_certificate = false
#
#   # Manual DNS validation (no Route53)
#   create_route53_records = false
#   wait_for_validation    = false
#
#   tags = local.common_tags
# }

# =============================================================================
# EC2 Instances
# =============================================================================

# EC2 Instances running Nginx (one per AZ)
# Reference: FR-003 (EC2 instance deployment with Nginx)
module "ec2_instance" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "6.1.4"

  for_each = local.instances

  name                        = "nginx-${each.key}"
  instance_type               = var.instance_type
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [module.ec2_sg.security_group_id]
  associate_public_ip_address = true

  # User data script for Nginx installation
  user_data = file("${path.module}/user-data.sh")

  tags = merge(local.common_tags, {
    Name = "nginx-${each.key}"
  })
}

# =============================================================================
# Application Load Balancer
# =============================================================================

# Application Load Balancer with HTTP�HTTPS redirect
# Reference: FR-007 (ALB with multi-AZ deployment)
module "alb" {
  source  = "app.terraform.io/hashi-demos-apj/alb/aws"
  version = "10.1.0"

  name               = "ec2-nginx-alb"
  load_balancer_type = "application"
  vpc_id             = data.aws_vpc.default.id
  subnets            = local.selected_subnets
  security_groups    = [module.alb_sg.security_group_id]

  # Disable deletion protection for development environment
  enable_deletion_protection = false

  # Listeners configuration
  # Note: Using HTTP-only for sandbox testing
  # Add HTTPS listener after ACM certificate validation completes
  listeners = {
    # HTTP listener: Forward to target group (for sandbox testing)
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ec2_instances"
      }
    }
  }

  # Target group configuration
  target_groups = {
    ec2_instances = {
      name_prefix       = "nginx-"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      vpc_id            = data.aws_vpc.default.id
      create_attachment = false # Using additional_target_group_attachments instead

      # Health check configuration
      health_check = {
        enabled             = true
        healthy_threshold   = var.health_check_threshold
        interval            = var.health_check_interval
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = var.health_check_threshold
      }
    }
  }

  # Target group attachments (EC2 instances)
  additional_target_group_attachments = {
    for k, v in module.ec2_instance : k => {
      target_group_key = "ec2_instances"
      target_id        = v.id
      port             = 80
    }
  }

  tags = local.common_tags
}
