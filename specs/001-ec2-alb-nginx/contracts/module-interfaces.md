# Module Interface Contracts

**Feature Branch**: `001-ec2-alb-nginx`
**Created**: 2025-12-17

This document defines the interface contracts for all private modules used in the EC2-ALB-NGINX infrastructure.

---

## 1. ALB Module Contract

**Source**: `app.terraform.io/hashi-demos-apj/alb/aws`
**Version**: `10.1.0`

### Required Inputs

```hcl
# VPC Configuration
vpc_id = string  # VPC ID where ALB will be created

# Network Configuration
subnets = list(string)  # Subnet IDs for ALB (minimum 2 from different AZs)

# Listeners Configuration
listeners = map(object({
  port            = number
  protocol        = string
  certificate_arn = optional(string)  # Required for HTTPS
  redirect        = optional(object({
    port        = string
    protocol    = string
    status_code = string
  }))
  forward = optional(object({
    target_group_key = string
  }))
}))

# Target Groups Configuration
target_groups = map(object({
  name_prefix = string
  protocol    = string
  port        = number
  target_type = string
  vpc_id      = string
  health_check = optional(object({
    enabled             = bool
    healthy_threshold   = number
    interval            = number
    matcher             = string
    path                = string
    port                = string
    protocol            = string
    timeout             = number
    unhealthy_threshold = number
  }))
}))
```

### Optional Inputs

```hcl
name                       = string  # ALB name (defaults to null)
load_balancer_type         = string  # "application" or "network" (default: "application")
internal                   = bool    # Internal ALB (default: false)
enable_deletion_protection = bool    # Deletion protection (default: true)
security_groups            = list(string)  # Security group IDs
tags                       = map(string)   # Resource tags

# Target group attachments
additional_target_group_attachments = map(object({
  target_group_key = string
  target_id        = string
  port             = number
}))
```

### Outputs

```hcl
dns_name    = string  # ALB DNS endpoint (PRIMARY)
arn         = string  # ALB ARN
id          = string  # ALB ID
zone_id     = string  # Route53 zone ID for ALB
target_groups = map(object({
  arn  = string
  name = string
}))
listeners = map(object({
  arn = string
}))
```

### Example Usage

```hcl
module "alb" {
  source  = "app.terraform.io/hashi-demos-apj/alb/aws"
  version = "10.1.0"

  name               = "ec2-nginx-alb"
  load_balancer_type = "application"
  vpc_id             = data.aws_vpc.default.id
  subnets            = local.selected_subnets
  security_groups    = [module.alb_sg.security_group_id]

  enable_deletion_protection = false

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
    }
  }

  additional_target_group_attachments = {
    for k, v in module.ec2_instance : k => {
      target_group_key = "ec2_instances"
      target_id        = v.id
      port             = 80
    }
  }

  tags = local.common_tags
}
```

---

## 2. EC2 Instance Module Contract

**Source**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws`
**Version**: `6.1.4`

### Required Inputs

```hcl
# Instance Configuration
instance_type = string  # EC2 instance type (e.g., "t3.micro")
ami           = string  # AMI ID to use
subnet_id     = string  # Subnet ID for instance placement
```

### Optional Inputs

```hcl
name                        = string       # Instance name
vpc_security_group_ids      = list(string) # Security group IDs
user_data                   = string       # User data script (base64 not required)
associate_public_ip_address = bool         # Assign public IP (default: false)
tags                        = map(string)  # Resource tags

# Advanced Configuration
ami_ssm_parameter           = string  # SSM parameter for AMI lookup
monitoring                  = bool    # Detailed monitoring (default: false)
ebs_optimized               = bool    # EBS optimization (default: false)
```

### Outputs

```hcl
id                           = string  # Instance ID
arn                          = string  # Instance ARN
private_ip                   = string  # Private IP address
public_ip                    = string  # Public IP address (if assigned)
availability_zone            = string  # AZ where instance is running
security_group_id            = string  # Security group ID (if created)
primary_network_interface_id = string  # Primary network interface ID
```

### Example Usage

```hcl
module "ec2_instance" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "6.1.4"

  for_each = local.instances

  name                        = "nginx-${each.key}"
  instance_type               = "t3.micro"
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [module.ec2_sg.security_group_id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user-data.sh", {
    hostname_suffix = each.key
  })

  tags = merge(local.common_tags, {
    Name = "nginx-${each.key}"
  })
}
```

---

## 3. Security Group Module Contract

**Source**: `app.terraform.io/hashi-demos-apj/security-group/aws`
**Version**: `5.3.1`

### Required Inputs

```hcl
vpc_id = string  # VPC ID where security group will be created
```

### Optional Inputs

```hcl
name        = string       # Security group name
description = string       # Security group description
tags        = map(string)  # Resource tags

# Ingress Rules (CIDR-based)
ingress_with_cidr_blocks = list(object({
  from_port   = number
  to_port     = number
  protocol    = string
  cidr_blocks = string
  description = string
}))

# Ingress Rules (Security Group reference)
ingress_with_source_security_group_id = list(object({
  from_port                = number
  to_port                  = number
  protocol                 = string
  source_security_group_id = string
  description              = string
}))

# Egress Rules (CIDR-based)
egress_with_cidr_blocks = list(object({
  from_port   = number
  to_port     = number
  protocol    = string
  cidr_blocks = string
  description = string
}))

# Egress Rules (Security Group reference)
egress_with_source_security_group_id = list(object({
  from_port                = number
  to_port                  = number
  protocol                 = string
  source_security_group_id = string
  description              = string
}))

# Named Rules
ingress_rules = list(string)  # Pre-defined rule names (e.g., "http-80-tcp")
egress_rules  = list(string)  # Pre-defined rule names
```

### Outputs

```hcl
security_group_id          = string  # Security group ID
security_group_arn         = string  # Security group ARN
security_group_name        = string  # Security group name
security_group_description = string  # Security group description
security_group_vpc_id      = string  # VPC ID
```

### Example Usage (ALB Security Group)

```hcl
module "alb_sg" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "5.3.1"

  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

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
```

### Example Usage (EC2 Security Group)

```hcl
module "ec2_sg" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "5.3.1"

  name        = "ec2-security-group"
  description = "Security group for EC2 web servers"
  vpc_id      = data.aws_vpc.default.id

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "HTTP from ALB only"
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

  tags = local.common_tags
}
```

---

## 4. ACM Module Contract

**Source**: `app.terraform.io/hashi-demos-apj/acm/aws`
**Version**: `6.1.1`

### Required Inputs

```hcl
domain_name       = string  # Primary domain name for certificate
validation_method = string  # "DNS" or "EMAIL"
```

### Optional Inputs

```hcl
subject_alternative_names = list(string)  # Additional domain names (SANs)
tags                      = map(string)   # Resource tags

# DNS Validation Configuration
create_route53_records  = bool           # Create Route53 records automatically (default: true)
wait_for_validation     = bool           # Wait for validation to complete (default: true)
validation_record_fqdns = list(string)   # External DNS validation FQDNs

# Route53 Configuration (if using)
zone_id = string  # Route53 hosted zone ID
```

### Outputs

```hcl
acm_certificate_arn                      = string  # Certificate ARN
acm_certificate_status                   = string  # Certificate status
acm_certificate_domain_validation_options = list(object({
  domain_name           = string
  resource_record_name  = string
  resource_record_type  = string
  resource_record_value = string
}))
distinct_domain_names = list(string)  # Distinct domains requiring validation
```

### Example Usage (Manual DNS Validation)

```hcl
module "acm" {
  source  = "app.terraform.io/hashi-demos-apj/acm/aws"
  version = "6.1.1"

  domain_name       = var.domain_name
  validation_method = "DNS"

  # Manual DNS validation (no Route53)
  create_route53_records = false
  wait_for_validation    = false

  tags = local.common_tags
}

# Output DNS validation records for manual creation
output "acm_dns_validation_records" {
  description = "Create these CNAME records in your DNS provider"
  value = {
    for dvo in module.acm.acm_certificate_domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
```

---

## 5. Integration Dependencies

### Module Dependency Order

```
1. Data Sources (VPC, Subnets, AMI)
   ↓
2. Security Groups
   ├── ALB Security Group
   └── EC2 Security Group (references ALB SG)
   ↓
3. ACM Certificate
   ↓
4. EC2 Instances (references EC2 SG)
   ↓
5. ALB (references ALB SG, EC2 instances, ACM cert)
```

### Cross-Module References

```hcl
# Security Group Chaining
module.ec2_sg.ingress → references → module.alb_sg.security_group_id
module.alb_sg.egress  → references → module.ec2_sg.security_group_id

# ALB → EC2 Target Attachment
module.alb.additional_target_group_attachments → references → module.ec2_instance[*].id

# ALB → ACM Certificate
module.alb.listeners.https.certificate_arn → references → module.acm.acm_certificate_arn

# EC2 → Security Group
module.ec2_instance[*].vpc_security_group_ids → references → module.ec2_sg.security_group_id

# ALB → Security Group
module.alb.security_groups → references → module.alb_sg.security_group_id
```

---

## 6. Validation Rules

### ALB Module Validation

- At least 2 subnets from different AZs required
- Listeners must have either `redirect` or `forward` action
- HTTPS listener requires valid `certificate_arn`
- Target group `target_type` must match attachment type

### EC2 Module Validation

- Instance type must exist in target region
- AMI must be compatible with instance type architecture
- Subnet must exist in VPC
- Security groups must exist in same VPC

### Security Group Module Validation

- Ingress/egress rules must have valid port ranges (1-65535)
- Protocol must be valid (tcp, udp, icmp, -1)
- Referenced security groups must exist in same VPC
- CIDR blocks must be valid IP ranges

### ACM Module Validation

- Domain name must be valid DNS format
- Validation method must be "DNS" or "EMAIL"
- If manual validation, `wait_for_validation` must be false

---

## 7. Error Handling

### Common Module Errors

**ALB Module**:
- `InvalidSubnet`: Subnets not in same VPC or insufficient AZs
- `InvalidSecurityGroup`: Security group not in ALB's VPC
- `CertificateNotFound`: ACM certificate ARN invalid or not ready
- `TargetNotFound`: EC2 instance ID doesn't exist

**EC2 Module**:
- `InvalidAMIID.NotFound`: AMI ID doesn't exist in region
- `InvalidSubnet.NotFound`: Subnet doesn't exist
- `InvalidGroup.NotFound`: Security group doesn't exist
- `InstanceLimitExceeded`: Account instance limit reached

**Security Group Module**:
- `InvalidVpcID.NotFound`: VPC doesn't exist
- `InvalidPermission.Duplicate`: Rule already exists
- `RulesPerSecurityGroupLimitExceeded`: Too many rules (default limit: 60)

**ACM Module**:
- `ValidationException`: Invalid domain name format
- `LimitExceededException`: Certificate limit reached (default: 2048)
- `InvalidDomainValidationOptionsException`: Invalid validation configuration

---

## Summary

These contracts define:

1. **Required and optional inputs** for each module
2. **Output values** available for downstream consumption
3. **Example usage patterns** for common scenarios
4. **Integration dependencies** between modules
5. **Validation rules** enforced by modules
6. **Error handling** for common failure scenarios

All modules follow HCP Terraform private registry standards with semantic versioning and comprehensive documentation.
