# Research: EC2 Infrastructure with ALB and Nginx

**Feature Branch**: `001-ec2-alb-nginx`
**Created**: 2025-12-17
**Status**: Complete

## Phase 0: Research Findings

This document consolidates research findings for all technical decisions required to implement the EC2-ALB-NGINX infrastructure.

---

## 1. AMI Selection for EC2 Instances

**Decision**: Use Amazon Linux 2023 (AL2023) AMI retrieved dynamically via SSM parameter

**Rationale**:
- AL2023 is the latest generation Amazon Linux with long-term support until 2028
- Provides quarterly security updates and patches
- Uses dnf package manager (modern replacement for yum)
- Optimized for AWS infrastructure with better performance
- SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` ensures automatic latest version retrieval
- No need to hardcode AMI IDs which become outdated

**Alternatives Considered**:
- Ubuntu 22.04 LTS: More familiar to some teams but requires different package management
- Amazon Linux 2: Older generation, end of support in 2025
- Hardcoded AMI ID: Requires manual updates and becomes stale

**Implementation**:
```hcl
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
```

---

## 2. Default VPC and Subnet Discovery

**Decision**: Use Terraform data sources to discover default VPC and select 2 subnets from different AZs

**Rationale**:
- Default VPC exists in all AWS regions by design
- Avoids manual subnet ID entry and hardcoding
- Dynamic selection ensures multi-AZ deployment
- Data sources validate VPC and subnet existence at plan time

**Alternatives Considered**:
- Create new VPC: Out of scope per requirements, increases complexity
- Hardcode subnet IDs: Not portable, requires manual updates per region/account
- Use all available subnets: Unnecessary for 2-instance deployment

**Implementation**:
```hcl
data "aws_vpc" "default" {
  default = true
}

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

# Select first 2 subnets from different AZs
locals {
  selected_subnets = slice(data.aws_subnets.default.ids, 0, 2)
}
```

---

## 3. User Data Script for Nginx Installation

**Decision**: Bash script with dnf package manager, systemd service enablement, and custom HTML content

**Rationale**:
- AL2023 uses dnf (not yum) for package management
- Systemd is the init system for AL2023
- Script must be idempotent for reliable provisioning
- Custom HTML validates load balancing across instances

**Alternatives Considered**:
- Cloud-init YAML: More complex for simple web server setup
- Configuration management (Ansible/Puppet): Out of scope for simple static content
- Docker container: Unnecessary complexity for static HTML

**Implementation**:
```bash
#!/bin/bash
set -e

# Update system and install nginx
dnf update -y
dnf install -y nginx

# Create custom index page with hostname and timestamp
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>EC2 ALB Nginx Infrastructure</title></head>
<body>
<h1>Welcome to EC2 ALB Nginx Infrastructure</h1>
<p>Server: $(hostname)</p>
<p>Timestamp: $(date)</p>
</body>
</html>
EOF

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

# Configure firewall for HTTP
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```

---

## 4. ALB Health Check Configuration

**Decision**: HTTP protocol on port 80, path `/`, 30s interval, 2 consecutive checks threshold

**Rationale**:
- HTTP health checks align with application protocol
- Root path `/` validates nginx is serving content
- 30-second interval balances responsiveness with network overhead
- 2 consecutive checks (healthy/unhealthy) follows AWS best practices for reliability
- 5-second timeout prevents false negatives from network latency

**Alternatives Considered**:
- TCP health checks: Less accurate, doesn't validate application layer
- 10-second interval: Too aggressive, may cause false negatives
- Single check threshold: Too sensitive to transient failures

**Implementation** (via ALB module):
```hcl
health_check = {
  enabled             = true
  healthy_threshold   = 2
  interval            = 30
  matcher             = "200"
  path                = "/"
  port                = "traffic-port"
  protocol            = "HTTP"
  timeout             = 5
  unhealthy_threshold = 2
}
```

---

## 5. ACM Certificate DNS Validation Strategy

**Decision**: Use ACM DNS validation with documented manual DNS record creation requirement

**Rationale**:
- DNS validation is more reliable than email validation
- No Route53 hosted zone available (per assumptions)
- Manual DNS record creation documented in deployment guide
- Provides fallback HTTP-only option for initial sandbox testing

**Alternatives Considered**:
- Email validation: Less reliable, requires access to domain email
- Self-signed certificate: Browser warnings, poor user experience
- Skip HTTPS: Violates security requirements (Priority P3)

**Implementation**:
```hcl
module "acm" {
  source  = "app.terraform.io/hashi-demos-apj/acm/aws"
  version = "6.1.1"

  domain_name       = var.domain_name
  validation_method = "DNS"

  # Manual DNS record creation required
  create_route53_records  = false
  wait_for_validation     = false

  tags = local.common_tags
}
```

**Documentation Required**:
- DNS validation records output for manual creation
- Step-by-step guide for adding CNAME records to DNS provider
- HTTP-only fallback configuration for testing

---

## 6. Security Group Architecture

**Decision**: Two security groups with reference-based rules (ALB → EC2)

**Rationale**:
- ALB security group: Public internet access on 80/443
- EC2 security group: Restricted access only from ALB security group
- Egress from EC2 to internet (0.0.0.0/0:80,443) for package downloads during user_data
- Security group references prevent circular dependencies
- Follows AWS security best practice of least privilege

**Alternatives Considered**:
- Single security group: Violates separation of concerns
- IP-based rules: Less flexible, requires updates on infrastructure changes
- No egress rules: Package installation fails during user_data

**Implementation**:
```hcl
# ALB Security Group
module "alb_sg" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "5.3.1"

  vpc_id = data.aws_vpc.default.id

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
}

# EC2 Security Group
module "ec2_sg" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "5.3.1"

  vpc_id = data.aws_vpc.default.id

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "HTTP from ALB"
    }
  ]

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
}
```

---

## 7. EC2 Instance Deployment Pattern

**Decision**: Use for_each with map of instance configurations across 2 AZs

**Rationale**:
- for_each provides stable resource addresses (better than count)
- Map keys define instance identifiers (e.g., "az-a", "az-b")
- Enables easy expansion or modification of instances
- Each instance gets unique subnet assignment

**Alternatives Considered**:
- count = 2: Less readable, resource addresses change on reorder
- Separate module calls: Unnecessary duplication
- Auto Scaling Group: Out of scope, adds complexity

**Implementation**:
```hcl
locals {
  instances = {
    "az-a" = {
      subnet_id = local.selected_subnets[0]
    }
    "az-b" = {
      subnet_id = local.selected_subnets[1]
    }
  }
}

module "ec2_instance" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "6.1.4"

  for_each = local.instances

  name                        = "nginx-${each.key}"
  instance_type               = "t3.micro"
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [module.ec2_sg.security_group_id]
  user_data                   = local.user_data_script
  associate_public_ip_address = true

  tags = local.common_tags
}
```

---

## 8. ALB Listener Configuration

**Decision**: Two listeners - HTTP redirect to HTTPS, HTTPS forward to target group

**Rationale**:
- HTTP listener (port 80): Redirects all traffic to HTTPS (301 permanent redirect)
- HTTPS listener (port 443): Forwards traffic to EC2 target group
- Meets security requirement for encrypted communication
- Standard AWS ALB pattern for web applications

**Alternatives Considered**:
- HTTP-only: Violates security requirements
- Terminate SSL at instances: More complex, less efficient
- HTTPS redirect on instances: Wastes ALB capabilities

**Implementation**:
```hcl
listeners = {
  http = {
    port     = 80
    protocol = "HTTP"
    redirect = {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  https = {
    port            = 443
    protocol        = "HTTPS"
    certificate_arn = module.acm.acm_certificate_arn
    forward = {
      target_group_key = "ec2_instances"
    }
  }
}
```

---

## 9. Target Group Configuration

**Decision**: Instance target type with HTTP protocol, health checks enabled

**Rationale**:
- Instance target type matches EC2 deployment (not IP or Lambda)
- HTTP protocol aligns with nginx configuration
- Health checks ensure only healthy instances receive traffic
- Deregistration delay minimizes connection disruptions

**Alternatives Considered**:
- IP target type: Unnecessary complexity for simple EC2 deployment
- TCP protocol: Less accurate health validation

**Implementation**:
```hcl
target_groups = {
  ec2_instances = {
    name_prefix = "nginx-"
    protocol    = "HTTP"
    port        = 80
    target_type = "instance"
    vpc_id      = data.aws_vpc.default.id

    health_check = {
      enabled             = true
      healthy_threshold   = 2
      interval            = 30
      matcher             = "200"
      path                = "/"
      port                = "traffic-port"
      protocol            = "HTTP"
      timeout             = 5
      unhealthy_threshold = 2
    }

    # Attach EC2 instances
    create_attachment = false  # Manual attachment via additional_target_group_attachments
  }
}

additional_target_group_attachments = {
  for k, v in module.ec2_instance : k => {
    target_group_key = "ec2_instances"
    target_id        = v.id
    port             = 80
  }
}
```

---

## 10. Resource Tagging Strategy

**Decision**: Consistent tags across all resources for identification and cost allocation

**Rationale**:
- Enables cost tracking by project and environment
- Identifies Terraform-managed resources
- Workspace tag links to HCP Terraform deployment context

**Implementation**:
```hcl
locals {
  common_tags = {
    environment  = "development"
    project      = "ec2-alb-nginx"
    managed-by   = "terraform"
    workspace    = "sandbox_ec2workspace"
  }
}
```

---

## 11. Module Version Strategy

**Decision**: Use exact versions for private modules to ensure consistency

**Rationale**:
- Private modules verified and tested at specific versions
- Prevents unexpected changes from module updates
- Aligns with organizational governance requirements

**Module Versions**:
- ALB module: `10.1.0`
- EC2 instance module: `6.1.4`
- Security group module: `5.3.1`
- ACM module: `6.1.1`

---

## 12. HCP Terraform Configuration

**Decision**: Use cloud block for remote execution in HCP Terraform workspace

**Rationale**:
- Workspace `sandbox_ec2workspace` pre-configured in organization `hashi-demos-apj`
- Project `sandbox` (ID: prj-QueMgU3LXgV2Ag7s) provides isolation
- AWS credentials pre-configured at workspace level
- Remote execution provides audit trail and state locking

**Implementation**:
```hcl
terraform {
  cloud {
    organization = "hashi-demos-apj"
    workspaces {
      name = "sandbox_ec2workspace"
    }
  }
}
```

---

## Summary

All technical decisions have been researched and documented. Key architectural patterns:

1. **Infrastructure as Code**: Private module consumption from HCP Terraform registry
2. **Security**: Multi-layer security groups, HTTPS enforcement, least privilege
3. **High Availability**: Multi-AZ deployment with health checks
4. **Automation**: Dynamic resource discovery, idempotent user data scripts
5. **Cost Optimization**: t3.micro instances, minimal resource footprint
6. **Maintainability**: Consistent tagging, version pinning, clear naming conventions

Implementation ready to proceed to Phase 1 (Design & Contracts).
