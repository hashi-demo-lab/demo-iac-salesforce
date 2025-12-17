# Data Model: EC2 Infrastructure with ALB and Nginx

**Feature Branch**: `001-ec2-alb-nginx`
**Created**: 2025-12-17
**Status**: Complete

## Overview

This document defines the data model for the EC2-ALB-NGINX infrastructure, including resource relationships, module inputs/outputs, and network topology.

---

## 1. Resource Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Default VPC                             │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Application Load Balancer                │ │
│  │  ┌──────────────┐              ┌──────────────┐            │ │
│  │  │ HTTP:80      │─────────────▶│ HTTPS:443    │            │ │
│  │  │ (Redirect)   │              │ (Forward)    │            │ │
│  │  └──────────────┘              └──────┬───────┘            │ │
│  │         │                              │                    │ │
│  │         │  ┌────────────────────────────┘                  │ │
│  │         │  │                                                │ │
│  │         ▼  ▼                                                │ │
│  │  ┌─────────────────────────────┐                           │ │
│  │  │     Target Group (HTTP:80)   │                           │ │
│  │  │  ┌─────────────────────────┐ │                           │ │
│  │  │  │ Health Check: HTTP:80 / │ │                           │ │
│  │  │  │ Interval: 30s           │ │                           │ │
│  │  │  │ Threshold: 2/2          │ │                           │ │
│  │  │  └─────────────────────────┘ │                           │ │
│  │  └────────┬────────────┬─────────┘                          │ │
│  │           │            │                                     │ │
│  └───────────┼────────────┼─────────────────────────────────────┘ │
│              │            │                                       │
│  ┌───────────▼──────────┐ ┌──────────▼───────────┐              │
│  │  Subnet AZ-A         │ │  Subnet AZ-B         │              │
│  │  ┌────────────────┐  │ │  ┌────────────────┐  │              │
│  │  │ EC2 Instance   │  │ │  │ EC2 Instance   │  │              │
│  │  │ nginx-az-a     │  │ │  │ nginx-az-b     │  │              │
│  │  │ t3.micro       │  │ │  │ t3.micro       │  │              │
│  │  │ Nginx:80       │  │ │  │ Nginx:80       │  │              │
│  │  └────────────────┘  │ │  └────────────────┘  │              │
│  └──────────────────────┘ └──────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────┐
│     ACM Certificate          │
│  ┌──────────────────────┐   │
│  │ DNS Validation        │   │
│  │ (Manual Record)       │   │
│  └──────────────────────┘   │
│            │                 │
│            ▼                 │
│  ┌──────────────────────┐   │
│  │ ALB HTTPS Listener   │   │
│  └──────────────────────┘   │
└─────────────────────────────┘

Security Groups:
┌────────────────────┐         ┌────────────────────┐
│   ALB SG           │────────▶│   EC2 SG           │
│                    │         │                    │
│ Ingress:           │         │ Ingress:           │
│  0.0.0.0/0:80      │         │  ALB_SG:80         │
│  0.0.0.0/0:443     │         │                    │
│                    │         │ Egress:            │
│ Egress:            │         │  0.0.0.0/0:80      │
│  EC2_SG:80         │         │  0.0.0.0/0:443     │
└────────────────────┘         └────────────────────┘
```

---

## 2. Entity Definitions

### 2.1 VPC (Default VPC)

**Purpose**: Network isolation and subnet allocation

**Attributes**:
- VPC ID: Discovered via data source
- CIDR Block: AWS-managed (typically 172.31.0.0/16)
- Region: ap-southeast-2
- Internet Gateway: Pre-attached

**Data Source**:
```hcl
data "aws_vpc" "default" {
  default = true
}
```

**Outputs**:
- `vpc_id`: Used for security group and subnet association

---

### 2.2 Subnets

**Purpose**: Network placement for EC2 instances and ALB across availability zones

**Attributes**:
- Subnet IDs: Discovered via data source
- Availability Zones: At least 2 distinct AZs required
- Type: Default subnets (public with internet access)

**Data Source**:
```hcl
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
```

**Selection Logic**:
```hcl
locals {
  selected_subnets = slice(data.aws_subnets.default.ids, 0, 2)
}
```

**Outputs**:
- `subnet_ids[0]`: AZ-A subnet for first EC2 instance and ALB
- `subnet_ids[1]`: AZ-B subnet for second EC2 instance and ALB

---

### 2.3 EC2 Instances

**Purpose**: Compute resources running Nginx web server

**Module**: `app.terraform.io/hashi-demos-apj/ec2-instance/aws` v6.1.4

**Attributes**:
- Name: `nginx-az-a`, `nginx-az-b`
- Instance Type: `t3.micro`
- AMI: Amazon Linux 2023 (dynamic via SSM)
- Subnet: One per AZ
- Security Group: EC2 security group
- User Data: Nginx installation script
- Public IP: Enabled for internet access

**Instance Map**:
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
```

**Module Inputs**:
- `name`: Instance identifier
- `instance_type`: "t3.micro"
- `ami`: SSM parameter value
- `subnet_id`: From selected subnets
- `vpc_security_group_ids`: [EC2 SG ID]
- `user_data`: Base64-encoded bash script
- `associate_public_ip_address`: true
- `tags`: Common tags

**Module Outputs**:
- `id`: Instance ID for target group attachment
- `private_ip`: Internal IP address
- `public_ip`: External IP address (if assigned)
- `arn`: Instance ARN

---

### 2.4 Application Load Balancer

**Purpose**: Layer 7 load balancer distributing HTTP/HTTPS traffic

**Module**: `app.terraform.io/hashi-demos-apj/alb/aws` v10.1.0

**Attributes**:
- Name: `ec2-nginx-alb`
- Type: `application`
- Scheme: `internet-facing`
- Subnets: Both selected subnets (multi-AZ)
- Security Group: ALB security group
- Deletion Protection: Disabled (development)

**Module Inputs**:
- `name`: "ec2-nginx-alb"
- `load_balancer_type`: "application"
- `internal`: false
- `subnets`: [subnet_az_a, subnet_az_b]
- `security_groups`: [ALB SG ID]
- `enable_deletion_protection`: false
- `listeners`: HTTP and HTTPS configuration
- `target_groups`: EC2 target group configuration
- `tags`: Common tags

**Module Outputs**:
- `id`: Load balancer ID
- `arn`: Load balancer ARN
- `dns_name`: Public DNS endpoint (PRIMARY OUTPUT)
- `zone_id`: Route53 zone ID for DNS records
- `target_groups`: Target group details

---

### 2.5 ALB Listeners

**Purpose**: Handle incoming HTTP/HTTPS traffic with routing rules

#### HTTP Listener (Port 80)

**Attributes**:
- Port: 80
- Protocol: HTTP
- Action: Redirect to HTTPS

**Configuration**:
```hcl
http = {
  port     = 80
  protocol = "HTTP"
  redirect = {
    port        = "443"
    protocol    = "HTTPS"
    status_code = "HTTP_301"
  }
}
```

#### HTTPS Listener (Port 443)

**Attributes**:
- Port: 443
- Protocol: HTTPS
- Certificate: ACM certificate ARN
- Action: Forward to target group

**Configuration**:
```hcl
https = {
  port            = 443
  protocol        = "HTTPS"
  certificate_arn = module.acm.acm_certificate_arn
  forward = {
    target_group_key = "ec2_instances"
  }
}
```

---

### 2.6 Target Group

**Purpose**: Logical grouping of EC2 instances with health monitoring

**Attributes**:
- Name Prefix: `nginx-`
- Protocol: HTTP
- Port: 80
- Target Type: `instance`
- VPC ID: Default VPC
- Health Check: HTTP on port 80 to path `/`

**Health Check Configuration**:
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

**State Transitions**:
- Initial: EC2 instance registered → health check pending
- Healthy: 2 consecutive successful checks (200 OK)
- Unhealthy: 2 consecutive failed checks (timeout or non-200)

**Target Attachments**:
```hcl
additional_target_group_attachments = {
  for k, v in module.ec2_instance : k => {
    target_group_key = "ec2_instances"
    target_id        = v.id
    port             = 80
  }
}
```

---

### 2.7 Security Groups

#### ALB Security Group

**Purpose**: Control inbound internet traffic to load balancer

**Module**: `app.terraform.io/hashi-demos-apj/security-group/aws` v5.3.1

**Ingress Rules**:
| Rule | From Port | To Port | Protocol | Source | Description |
|------|-----------|---------|----------|--------|-------------|
| HTTP | 80 | 80 | TCP | 0.0.0.0/0 | HTTP from internet |
| HTTPS | 443 | 443 | TCP | 0.0.0.0/0 | HTTPS from internet |

**Egress Rules**:
| Rule | From Port | To Port | Protocol | Destination | Description |
|------|-----------|---------|----------|-------------|-------------|
| EC2 | 80 | 80 | TCP | EC2_SG | HTTP to EC2 instances |

**Module Inputs**:
- `name`: "alb-security-group"
- `vpc_id`: Default VPC ID
- `ingress_with_cidr_blocks`: HTTP/HTTPS rules
- `egress_with_source_security_group_id`: EC2 SG reference
- `tags`: Common tags

---

#### EC2 Security Group

**Purpose**: Restrict inbound traffic to ALB only, allow outbound package downloads

**Module**: `app.terraform.io/hashi-demos-apj/security-group/aws` v5.3.1

**Ingress Rules**:
| Rule | From Port | To Port | Protocol | Source | Description |
|------|-----------|---------|----------|--------|-------------|
| HTTP | 80 | 80 | TCP | ALB_SG | HTTP from ALB only |

**Egress Rules**:
| Rule | From Port | To Port | Protocol | Destination | Description |
|------|-----------|---------|----------|-------------|-------------|
| HTTP | 80 | 80 | TCP | 0.0.0.0/0 | Package downloads |
| HTTPS | 443 | 443 | TCP | 0.0.0.0/0 | Package downloads |

**Module Inputs**:
- `name`: "ec2-security-group"
- `vpc_id`: Default VPC ID
- `ingress_with_source_security_group_id`: ALB SG reference
- `egress_with_cidr_blocks`: HTTP/HTTPS rules
- `tags`: Common tags

---

### 2.8 ACM Certificate

**Purpose**: TLS/SSL certificate for HTTPS encryption

**Module**: `app.terraform.io/hashi-demos-apj/acm/aws` v6.1.1

**Attributes**:
- Domain Name: User-provided (variable)
- Validation Method: DNS
- Validation Records: Manual creation required
- Wait for Validation: false (manual process)

**Module Inputs**:
- `domain_name`: var.domain_name
- `validation_method`: "DNS"
- `create_route53_records`: false
- `wait_for_validation`: false
- `tags`: Common tags

**Module Outputs**:
- `acm_certificate_arn`: Certificate ARN for ALB listener
- `acm_certificate_domain_validation_options`: DNS records for manual creation

**Validation Process**:
1. Terraform creates ACM certificate request
2. ACM provides DNS validation records
3. User manually creates CNAME records in DNS provider
4. ACM validates domain ownership
5. Certificate becomes available for ALB

---

## 3. Module Input/Output Mappings

### Data Flow: VPC Discovery → Subnet Selection → Resource Creation

```
Data Sources
├── aws_vpc.default
│   └── outputs: vpc_id
├── aws_subnets.default
│   └── outputs: ids (list of subnet IDs)
└── aws_ssm_parameter.amazon_linux_2023
    └── outputs: value (AMI ID)

Local Values
├── selected_subnets = slice(data.aws_subnets.default.ids, 0, 2)
├── instances = map of instance configurations
└── common_tags = resource tags

Module: security-group (ALB)
├── inputs: vpc_id, ingress_with_cidr_blocks
└── outputs: security_group_id → ALB module, EC2 SG egress

Module: security-group (EC2)
├── inputs: vpc_id, ingress_with_source_security_group_id (ALB SG)
└── outputs: security_group_id → EC2 module

Module: acm
├── inputs: domain_name, validation_method
└── outputs: acm_certificate_arn → ALB listener

Module: ec2-instance (for_each)
├── inputs: ami, subnet_id, vpc_security_group_ids (EC2 SG)
└── outputs: id → target group attachment

Module: alb
├── inputs:
│   ├── subnets (selected_subnets)
│   ├── security_groups (ALB SG)
│   ├── listeners (HTTP redirect, HTTPS forward)
│   ├── target_groups (EC2 instances)
│   └── additional_target_group_attachments (EC2 instance IDs)
└── outputs: dns_name (PRIMARY OUTPUT)
```

---

## 4. Network Topology

### Traffic Flow: User → ALB → EC2 Instances

```
┌─────────────┐
│   Internet  │
│   User      │
└──────┬──────┘
       │
       │ 1. HTTP Request (http://alb-dns-name)
       │
       ▼
┌─────────────────────────┐
│ ALB Security Group      │
│ Ingress: 0.0.0.0/0:80  │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│ ALB HTTP Listener :80   │
│ Action: Redirect        │
└──────┬──────────────────┘
       │
       │ 2. 301 Redirect to HTTPS
       │
       ▼
┌─────────────────────────┐
│ ALB HTTPS Listener :443 │
│ TLS Termination (ACM)   │
└──────┬──────────────────┘
       │
       │ 3. Decrypted HTTP → Target Group
       │
       ▼
┌──────────────────────────┐
│ Target Group             │
│ Health: Check HTTP:80 /  │
│ Targets: 2 EC2 instances │
└──────┬───────────┬───────┘
       │           │
       │           │ 4. Round-robin distribution
       │           │
       ▼           ▼
┌──────────┐   ┌──────────┐
│ EC2 AZ-A │   │ EC2 AZ-B │
│ Nginx:80 │   │ Nginx:80 │
└──────┬───┘   └───┬──────┘
       │           │
       │           │ 5. HTTP Response with HTML
       │           │
       ▼           ▼
┌─────────────────────────┐
│ EC2 Security Group      │
│ Ingress: ALB_SG:80     │
└─────────────────────────┘
```

### Health Check Flow

```
┌─────────────────────────┐
│ Target Group            │
│ Health Check Config     │
└──────┬──────────────────┘
       │
       │ Every 30 seconds
       │
       ▼
┌─────────────────────────┐
│ HTTP GET / :80          │
│ Timeout: 5s             │
└──────┬──────────────────┘
       │
       ▼
┌──────────────────────────┐
│ EC2 Instance: Nginx      │
│ Response: 200 OK         │
│ Body: HTML with hostname │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Health Status:           │
│ - 2 consecutive success  │
│   → Healthy              │
│ - 2 consecutive fail     │
│   → Unhealthy            │
└──────────────────────────┘
```

---

## 5. Variable Definitions

### Required Variables

```hcl
variable "domain_name" {
  description = "Domain name for ACM certificate (e.g., example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid DNS domain format."
  }
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}
```

### Optional Variables

```hcl
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "health_check_threshold" {
  description = "Number of consecutive health checks for healthy/unhealthy status"
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_threshold >= 2 && var.health_check_threshold <= 10
    error_message = "Health check threshold must be between 2 and 10."
  }
}
```

---

## 6. Output Definitions

### Primary Outputs

```hcl
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application)"
  value       = module.alb.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_groups["ec2_instances"].arn
}
```

### Instance Outputs

```hcl
output "ec2_instance_ids" {
  description = "IDs of the EC2 instances"
  value       = { for k, v in module.ec2_instance : k => v.id }
}

output "ec2_private_ips" {
  description = "Private IP addresses of EC2 instances"
  value       = { for k, v in module.ec2_instance : k => v.private_ip }
}

output "ec2_public_ips" {
  description = "Public IP addresses of EC2 instances (if assigned)"
  value       = { for k, v in module.ec2_instance : k => v.public_ip }
}
```

### Certificate Outputs

```hcl
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.acm.acm_certificate_arn
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for manual creation in your DNS provider"
  value       = module.acm.acm_certificate_domain_validation_options
}
```

### Security Group Outputs

```hcl
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb_sg.security_group_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.ec2_sg.security_group_id
}
```

---

## 7. Dependency Graph

```
Execution Order (Terraform determines automatically):

Level 1 (Data Sources):
├── data.aws_vpc.default
├── data.aws_subnets.default
└── data.aws_ssm_parameter.amazon_linux_2023

Level 2 (Locals):
└── locals (selected_subnets, instances, common_tags)

Level 3 (Security Groups):
├── module.alb_sg
└── module.ec2_sg (depends on alb_sg for egress rule)

Level 4 (ACM Certificate):
└── module.acm

Level 5 (EC2 Instances):
└── module.ec2_instance[*] (depends on ec2_sg)

Level 6 (Application Load Balancer):
└── module.alb (depends on alb_sg, ec2_instance, acm)
```

**Critical Dependencies**:
- ALB module MUST wait for EC2 instances (target attachments)
- EC2 SG egress MUST reference ALB SG (security group chaining)
- HTTPS listener MUST wait for ACM certificate ARN

---

## Summary

This data model provides:

1. **Clear Resource Relationships**: VPC → Subnets → EC2/ALB → Security Groups
2. **Module Integration**: Input/output mappings between private modules
3. **Network Topology**: Traffic flow from internet to EC2 instances
4. **Security Architecture**: Multi-layer security groups with least privilege
5. **Health Monitoring**: Target group health checks with state transitions
6. **Variable Management**: Required vs optional inputs with validation
7. **Output Strategy**: Key values for downstream consumption and testing

Ready to proceed to Phase 2 (Task Generation).
