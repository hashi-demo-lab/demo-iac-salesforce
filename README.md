# EC2 Infrastructure with ALB and Nginx

Production-ready Terraform configuration for deploying a highly available static web infrastructure on AWS using Application Load Balancer and EC2 instances running Nginx.

## Overview

This infrastructure deploys:

- **Application Load Balancer (ALB)**: Internet-facing load balancer with HTTP→HTTPS redirect
- **EC2 Instances**: 2x t3.micro instances running Nginx across separate availability zones
- **Security Groups**: Multi-layer security with least privilege access
- **ACM Certificate**: TLS/SSL certificate with DNS validation
- **Health Checks**: Automated health monitoring with 30-second intervals

### Architecture

```
Internet → ALB (HTTP:80 → HTTPS:443) → Target Group → EC2 Instances (Nginx:80)
           ↓
        ACM Certificate (TLS Termination)
           ↓
        Security Groups (ALB ← → EC2)
```

## Prerequisites

### Required

1. **HCP Terraform Account**
   - Organization: `hashi-demos-apj`
   - Project ID: `prj-QueMgU3LXgV2Ag7s`
   - Workspace: `sandbox_ec2workspace` (automatically created)

2. **AWS Credentials**
   - AWS account with permissions to create EC2, ALB, ACM, and VPC resources
   - Credentials configured in HCP Terraform workspace variable sets
   - Region: `ap-southeast-2` (Sydney)

3. **AWS Resources**
   - Default VPC in ap-southeast-2 region
   - At least 2 default subnets in different availability zones
   - Service quotas for 2 t3.micro instances and 1 ALB

4. **DNS Provider**
   - Access to DNS management for domain validation
   - Ability to create CNAME records for ACM certificate validation

5. **Local Tools**
   - Terraform >= 1.5.0
   - AWS CLI (for verification)
   - GitHub CLI (`gh`) authenticated

### Recommended

- Domain name for ACM certificate (e.g., `example.com`)
- Familiarity with HCP Terraform remote execution
- AWS Systems Manager Session Manager for EC2 access

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd <repository-directory>
```

### 2. Set Required Variables

Create a `terraform.tfvars` file (not committed to git):

```hcl
domain_name = "yourdomain.com"  # REQUIRED: Replace with your domain
environment = "development"      # Optional: development, staging, production
```

Or export as environment variables:

```bash
export TF_VAR_domain_name="yourdomain.com"
export TF_VAR_environment="development"
```

### 3. Initialize Terraform

```bash
terraform init
```

This will:
- Connect to HCP Terraform workspace `sandbox_ec2workspace`
- Download private modules from `app.terraform.io/hashi-demos-apj/`
- Initialize AWS provider v6.19.0+

### 4. Review Infrastructure Plan

```bash
terraform plan
```

Expected output: ~15 resources to be created including:
- 1 Application Load Balancer
- 2 EC2 instances (t3.micro)
- 2 Security groups
- 1 ACM certificate
- 2 ALB listeners (HTTP, HTTPS)
- 1 Target group with attachments

### 5. Deploy Infrastructure

```bash
terraform apply
```

Review the plan and type `yes` to confirm deployment.

**Estimated deployment time**: 8-10 minutes (excluding DNS validation)

### 6. Configure ACM DNS Validation

After deployment, retrieve DNS validation records:

```bash
terraform output acm_certificate_validation_records
```

Create the displayed CNAME record in your DNS provider:

```
Name:  _abc123.yourdomain.com
Type:  CNAME
Value: _xyz456.acm-validations.aws.
TTL:   300
```

**DNS propagation time**: 5-30 minutes depending on DNS provider

### 7. Verify Deployment

Check target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-2
```

Both instances should show `State: healthy` after ~2 minutes.

### 8. Test Application

Get ALB DNS name:

```bash
terraform output alb_dns_name
```

Test HTTP redirect:

```bash
curl -I http://<alb-dns-name>
# Expected: 301 redirect to HTTPS
```

Test HTTPS (after DNS validation):

```bash
curl https://<alb-dns-name>
# Expected: 200 OK with HTML content
```

Test load balancing:

```bash
for i in {1..10}; do
  curl -s https://<alb-dns-name> | grep "Server:"
done
# Expected: Alternating instance IDs
```

## File Structure

```
.
├── terraform.tf           # Terraform version and HCP backend configuration
├── provider.tf            # AWS provider configuration (ap-southeast-2)
├── variables.tf           # Input variable declarations with validation
├── locals.tf              # Local values (subnet selection, instance map, tags)
├── data.tf                # Data sources (VPC, subnets, AMI)
├── main.tf                # Module declarations (ALB, EC2, SG, ACM)
├── outputs.tf             # Output values (DNS name, ARNs, IPs)
├── user-data.sh           # EC2 user data script for Nginx installation
├── .gitignore             # Git ignore patterns (state files, credentials)
└── README.md              # This file
```

## Variables

### Required Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `domain_name` | string | Domain name for ACM certificate | `"example.com"` |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | `"development"` | Environment name (development, staging, production) |
| `instance_type` | string | `"t3.micro"` | EC2 instance type for web servers |
| `health_check_interval` | number | `30` | Health check interval in seconds (5-300) |
| `health_check_threshold` | number | `2` | Consecutive health checks for status change (2-10) |

## Outputs

### Primary Outputs

| Output | Description |
|--------|-------------|
| `alb_dns_name` | ALB DNS endpoint (use this to access the application) |
| `alb_arn` | Application Load Balancer ARN |
| `target_group_arn` | Target group ARN |

### Instance Outputs

| Output | Description |
|--------|-------------|
| `ec2_instance_ids` | Map of EC2 instance IDs (`az-a`, `az-b`) |
| `ec2_private_ips` | Map of private IP addresses |
| `ec2_public_ips` | Map of public IP addresses |

### Certificate Outputs

| Output | Description |
|--------|-------------|
| `acm_certificate_arn` | ACM certificate ARN |
| `acm_certificate_validation_records` | DNS validation records for manual creation |

### Security Group Outputs

| Output | Description |
|--------|-------------|
| `alb_security_group_id` | ALB security group ID |
| `ec2_security_group_id` | EC2 security group ID |

## Private Modules

All infrastructure is provisioned using HCP Terraform private modules:

| Module | Source | Version |
|--------|--------|---------|
| ALB | `app.terraform.io/hashi-demos-apj/alb/aws` | 10.1.0 |
| EC2 Instance | `app.terraform.io/hashi-demos-apj/ec2-instance/aws` | 6.1.4 |
| Security Group | `app.terraform.io/hashi-demos-apj/security-group/aws` | 5.3.1 |
| ACM | `app.terraform.io/hashi-demos-apj/acm/aws` | 6.1.1 |

## Security Considerations

### Network Security

- **ALB Security Group**: Allows HTTP/HTTPS from internet (0.0.0.0/0), egress only to EC2 SG:80
- **EC2 Security Group**: Allows HTTP:80 only from ALB SG, egress to 0.0.0.0/0:80,443 for package downloads
- **No SSH Access**: Use AWS Systems Manager Session Manager for EC2 access
- **Least Privilege**: Security groups reference each other (no IP-based rules between tiers)

### Data Protection

- **Encryption in Transit**: TLS 1.2+ enforced at ALB with ACM certificate
- **HTTP Redirect**: All HTTP traffic automatically redirected to HTTPS (301)
- **No Credentials in Code**: AWS credentials managed via HCP Terraform workspace variable sets

### Application Security

- **Static Content Only**: No dynamic code execution, minimal attack surface
- **Health Checks**: Automatic detection and removal of unhealthy instances
- **Instance Hardening**: Latest Amazon Linux 2023 AMI with firewalld configured

## Cost Estimation

**Monthly cost for development environment** (ap-southeast-2 region):

| Resource | Type | Quantity | Unit Cost | Monthly Cost |
|----------|------|----------|-----------|--------------|
| EC2 Instances | t3.micro | 2 | $7.50/mo | $15.00 |
| ALB | Application | 1 | $16.20/mo | $16.20 |
| Data Transfer | Minimal | <1GB | $0.09/GB | $0.10 |
| ACM Certificate | - | 1 | Free | $0.00 |
| **Total** | | | | **~$31.30/mo** |

**Assumptions**:
- Instances running 24/7
- Minimal traffic (<1GB/month)
- No additional EBS volumes
- Free tier not applied

**Cost optimization**:
- Use t3.micro (smallest burstable instance type)
- Single ALB serving multiple applications
- Development environment tags for cost tracking

## Troubleshooting

### Common Issues

#### 1. Default VPC Not Found

**Error**: `Error: no matching VPC found`

**Solution**:
```bash
# Create default VPC if deleted
aws ec2 create-default-vpc --region ap-southeast-2
```

#### 2. Insufficient Subnet Count

**Error**: `Error: insufficient subnets`

**Solution**: Ensure at least 2 default subnets exist in different AZs. Create manually if needed.

#### 3. ACM Certificate Pending Validation

**Symptom**: HTTPS returns "503 Service Unavailable"

**Solution**:
1. Check certificate status: `aws acm describe-certificate --certificate-arn <arn> --region ap-southeast-2`
2. Verify CNAME record created in DNS provider
3. Wait 5-30 minutes for DNS propagation

#### 4. Target Instances Unhealthy

**Symptom**: Both targets show `unhealthy` status

**Solution**:
```bash
# Check EC2 system logs
aws ec2 get-console-output --instance-id <instance-id> --region ap-southeast-2

# Verify nginx is running via Session Manager
aws ssm start-session --target <instance-id> --region ap-southeast-2
sudo systemctl status nginx
```

#### 5. Module Download Failed

**Error**: `Error: Failed to download module`

**Solution**: Verify HCP Terraform authentication and module registry permissions:
```bash
terraform login
```

#### 6. Workspace Not Found

**Error**: `Error: workspace not found`

**Solution**: The workspace `sandbox_ec2workspace` should be automatically created during first `terraform init`. If it fails, create manually in HCP Terraform UI or via API.

### Health Check Debugging

View health check configuration:

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-2
```

Common unhealthy reasons:
- `Target.Timeout`: Health check timeout (check nginx is running)
- `Target.FailedHealthChecks`: HTTP non-200 response (check nginx configuration)
- `Target.NotRegistered`: Instance not yet registered (wait 30 seconds)

### Network Connectivity

Test ALB connectivity:

```bash
# Test DNS resolution
nslookup <alb-dns-name>

# Test HTTP redirect
curl -v http://<alb-dns-name>

# Test HTTPS (after certificate validation)
curl -v https://<alb-dns-name>
```

Test EC2 instance connectivity (should timeout - security group blocks):

```bash
# Should timeout (this is expected - security allows only ALB)
curl http://<ec2-public-ip>
```

## Cleanup

### Destroy Infrastructure

**Warning**: This will permanently delete all resources.

```bash
terraform destroy
```

Review the plan and type `yes` to confirm destruction.

**Estimated destruction time**: 5-8 minutes

### Manual Cleanup

If `terraform destroy` fails, manually delete resources in this order:

1. ALB target group attachments
2. Application Load Balancer
3. Target groups
4. EC2 instances
5. Security groups (EC2 SG first, then ALB SG)
6. ACM certificate (delete DNS validation records)

### Workspace Cleanup

HCP Terraform workspace remains for future deployments. To delete:

1. Navigate to HCP Terraform UI
2. Select workspace `sandbox_ec2workspace`
3. Settings → Destruction and Deletion → Delete workspace

## High Availability Testing

### Test Failover

1. Stop nginx on one instance:
```bash
aws ssm start-session --target <instance-id-az-a> --region ap-southeast-2
sudo systemctl stop nginx
```

2. Verify health check detects failure (within 60 seconds):
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-2
```

3. Test continued availability:
```bash
curl https://<alb-dns-name>
# Should still return 200 OK from healthy instance
```

4. Restart nginx:
```bash
sudo systemctl start nginx
```

5. Verify automatic recovery (within 60 seconds):
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-southeast-2
```

### Expected Behavior

- **Failover time**: <60 seconds (2 failed health checks × 30s interval)
- **Recovery time**: <60 seconds (2 successful health checks × 30s interval)
- **No user-visible errors**: Traffic continues via healthy instance
- **Automatic recovery**: No manual intervention required

## Production Deployment

### Recommended Changes

For production environments, modify:

1. **Enable deletion protection**:
```hcl
# In main.tf
enable_deletion_protection = true
```

2. **Use custom domain with Route53**:
```hcl
# Add Route53 alias record for ALB
resource "aws_route53_record" "alb" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}
```

3. **Increase instance size**:
```hcl
instance_type = "t3.small"  # or larger based on load
```

4. **Add CloudWatch alarms**:
- ALB 5XX error rate
- Target unhealthy count
- EC2 CPU utilization

5. **Enable access logging**:
```hcl
# In main.tf ALB module
access_logs = {
  bucket  = "your-log-bucket"
  enabled = true
}
```

6. **Use custom VPC** instead of default VPC
7. **Add WAF rules** for additional security
8. **Enable auto scaling** for EC2 instances
9. **Configure backup strategy** for configuration

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Review HCP Terraform run logs
3. Check AWS CloudWatch logs for EC2 instances
4. Verify module documentation in private registry

## License

This infrastructure code is provided as-is for demonstration purposes.

## References

- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS ACM Documentation](https://docs.aws.amazon.com/acm/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.19.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.26.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | app.terraform.io/hashi-demos-apj/alb/aws | 10.1.0 |
| <a name="module_alb_sg"></a> [alb\_sg](#module\_alb\_sg) | app.terraform.io/hashi-demos-apj/security-group/aws | 5.3.1 |
| <a name="module_ec2_instance"></a> [ec2\_instance](#module\_ec2\_instance) | app.terraform.io/hashi-demos-apj/ec2-instance/aws | 6.1.4 |
| <a name="module_ec2_sg"></a> [ec2\_sg](#module\_ec2\_sg) | app.terraform.io/hashi-demos-apj/security-group/aws | 5.3.1 |

## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for ACM certificate (e.g., example.com or sub.example.com). Optional for HTTP-only deployments. | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (development, staging, production) | `string` | `"development"` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Health check interval in seconds | `number` | `30` | no |
| <a name="input_health_check_threshold"></a> [health\_check\_threshold](#input\_health\_check\_threshold) | Number of consecutive health checks for healthy/unhealthy status | `number` | `2` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for web servers | `string` | `"t3.micro"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer (use this to access the application) |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | ID of the ALB security group |
| <a name="output_ec2_instance_ids"></a> [ec2\_instance\_ids](#output\_ec2\_instance\_ids) | IDs of the EC2 instances |
| <a name="output_ec2_private_ips"></a> [ec2\_private\_ips](#output\_ec2\_private\_ips) | Private IP addresses of EC2 instances |
| <a name="output_ec2_public_ips"></a> [ec2\_public\_ips](#output\_ec2\_public\_ips) | Public IP addresses of EC2 instances (if assigned) |
| <a name="output_ec2_security_group_id"></a> [ec2\_security\_group\_id](#output\_ec2\_security\_group\_id) | ID of the EC2 security group |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the target group |
<!-- END_TF_DOCS -->
