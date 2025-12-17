# Quickstart Guide: EC2 Infrastructure with ALB and Nginx

**Feature Branch**: `001-ec2-alb-nginx`
**Created**: 2025-12-17

This guide provides step-by-step instructions for deploying the EC2-ALB-NGINX infrastructure to HCP Terraform.

---

## Prerequisites

Before starting, ensure you have:

1. **HCP Terraform Access**:
   - Organization: `hashi-demos-apj`
   - Project: `sandbox` (ID: prj-QueMgU3LXgV2Ag7s)
   - Workspace: `sandbox_ec2workspace`

2. **AWS Credentials**: Pre-configured in HCP Terraform workspace variables

3. **Domain Name**: For ACM certificate (e.g., example.com)

4. **DNS Provider Access**: For manual DNS validation record creation

5. **Git Repository**: Feature branch `001-ec2-alb-nginx` checked out

6. **Terraform CLI**: Version 1.5+ installed locally

---

## Step 1: Clone Repository and Checkout Branch

```bash
# Clone the repository
git clone <repository-url>
cd <repository-name>

# Checkout feature branch
git checkout 001-ec2-alb-nginx
```

---

## Step 2: Review Terraform Configuration

### File Structure

```
/
├── main.tf              # Module declarations for ALB, EC2, Security Groups, ACM
├── variables.tf         # Input variable declarations
├── outputs.tf           # Output declarations (ALB DNS, instance IDs, etc.)
├── locals.tf            # Local value computations
├── provider.tf          # AWS provider configuration
├── terraform.tf         # Terraform version constraints
├── override.tf          # HCP Terraform backend configuration (testing)
├── sandbox.auto.tfvars  # Variable values for sandbox deployment
└── README.md            # Deployment documentation
```

### Key Configuration Files

**terraform.tf** - Terraform version and backend:
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**override.tf** - HCP Terraform backend (for testing):
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

## Step 3: Configure Variables

### Required Variables

Edit `sandbox.auto.tfvars`:

```hcl
# AWS Region
region = "ap-southeast-2"

# Domain for ACM certificate
domain_name = "your-domain.com"  # Replace with your domain

# Environment
environment = "development"

# Optional: Override instance type
# instance_type = "t3.micro"  # Default is already t3.micro
```

### Validation

Terraform will validate:
- Domain name format (valid DNS domain)
- Environment value (development, staging, production)
- Region is valid AWS region

---

## Step 4: Initialize Terraform

Configure HCP Terraform credentials:

```bash
# Set TFE_TOKEN environment variable (if not already set)
export TFE_TOKEN="your-hcp-terraform-token"

# Create Terraform credentials file
mkdir -p ~/.terraform.d
cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF
```

Initialize Terraform:

```bash
terraform init
```

Expected output:
```
Initializing Terraform Cloud...
Initializing modules...
- alb in app.terraform.io/hashi-demos-apj/alb/aws
- ec2_instance in app.terraform.io/hashi-demos-apj/ec2-instance/aws
- alb_sg in app.terraform.io/hashi-demos-apj/security-group/aws
- ec2_sg in app.terraform.io/hashi-demos-apj/security-group/aws
- acm in app.terraform.io/hashi-demos-apj/acm/aws

Terraform has been successfully initialized!
```

---

## Step 5: Validate Configuration

Run Terraform validation:

```bash
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

---

## Step 6: Review Terraform Plan

Generate execution plan:

```bash
terraform plan
```

Review the plan output:
- **Data Sources**: VPC, Subnets, AMI lookup
- **Security Groups**: ALB SG (2 ingress rules), EC2 SG (1 ingress, 2 egress)
- **ACM Certificate**: Certificate request with DNS validation
- **EC2 Instances**: 2 instances (nginx-az-a, nginx-az-b)
- **ALB**: Application load balancer with HTTP and HTTPS listeners
- **Target Group**: Instance targets with health checks
- **Target Attachments**: 2 instance attachments

Expected resource count:
```
Plan: 15 to add, 0 to change, 0 to destroy.
```

---

## Step 7: Apply Terraform Configuration

Deploy infrastructure:

```bash
terraform apply
```

Review the plan and type `yes` to confirm.

**Note**: The apply will complete but the HTTPS listener will not be fully functional until DNS validation is complete (next step).

---

## Step 8: Complete ACM DNS Validation

### Retrieve Validation Records

After apply completes, get DNS validation records:

```bash
terraform output acm_certificate_validation_records
```

Example output:
```json
{
  "your-domain.com" = {
    "name"  = "_abc123def456.your-domain.com."
    "type"  = "CNAME"
    "value" = "_xyz789.acm-validations.aws."
  }
}
```

### Create DNS Records

**Option 1: Using CloudFlare**:
1. Log in to CloudFlare dashboard
2. Select your domain
3. Go to DNS settings
4. Add CNAME record:
   - Name: `_abc123def456` (remove domain suffix)
   - Target: `_xyz789.acm-validations.aws.`
   - TTL: Automatic

**Option 2: Using Route53 (if you have a hosted zone)**:
```bash
# This is automated if you set create_route53_records = true in ACM module
# Manual creation not required
```

**Option 3: Using Other DNS Providers**:
- Follow your DNS provider's documentation for adding CNAME records
- Use the values from the terraform output

### Wait for Validation

ACM validation typically completes within 5-30 minutes after DNS records are created:

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region ap-southeast-2
```

Look for `"Status": "ISSUED"` in the output.

---

## Step 9: Access the Application

### Get ALB DNS Name

```bash
terraform output alb_dns_name
```

Example output:
```
ec2-nginx-alb-1234567890.ap-southeast-2.elb.amazonaws.com
```

### Test HTTP (should redirect to HTTPS)

```bash
curl -I http://<alb-dns-name>
```

Expected response:
```
HTTP/1.1 301 Moved Permanently
Location: https://<alb-dns-name>:443/
```

### Test HTTPS (after DNS validation completes)

```bash
curl https://<alb-dns-name>
```

Expected response:
```html
<!DOCTYPE html>
<html>
<head><title>EC2 ALB Nginx Infrastructure</title></head>
<body>
<h1>Welcome to EC2 ALB Nginx Infrastructure</h1>
<p>Server: ip-172-31-x-x.ap-southeast-2.compute.internal</p>
<p>Timestamp: Tue Dec 17 12:34:56 UTC 2025</p>
</body>
</html>
```

**Note**: If DNS validation is not yet complete, HTTPS access will fail with SSL errors.

---

## Step 10: Verify High Availability

### Check Target Health

```bash
# Get target group ARN
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)

# Describe target health
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --region ap-southeast-2
```

Expected output:
```json
{
  "TargetHealthDescriptions": [
    {
      "Target": {
        "Id": "i-abc123",
        "Port": 80
      },
      "HealthCheckPort": "80",
      "TargetHealth": {
        "State": "healthy"
      }
    },
    {
      "Target": {
        "Id": "i-def456",
        "Port": 80
      },
      "HealthCheckPort": "80",
      "TargetHealth": {
        "State": "healthy"
      }
    }
  ]
}
```

### Test Load Balancing

Run multiple requests to see different server hostnames:

```bash
for i in {1..10}; do
  curl -s https://<alb-dns-name> | grep "Server:"
done
```

Expected output (alternating between instances):
```
<p>Server: ip-172-31-1-10.ap-southeast-2.compute.internal</p>
<p>Server: ip-172-31-2-20.ap-southeast-2.compute.internal</p>
<p>Server: ip-172-31-1-10.ap-southeast-2.compute.internal</p>
<p>Server: ip-172-31-2-20.ap-southeast-2.compute.internal</p>
...
```

---

## Step 11: Review HCP Terraform Workspace

1. Open HCP Terraform UI: https://app.terraform.io
2. Navigate to: Organizations → hashi-demos-apj → Projects → sandbox → sandbox_ec2workspace
3. Review:
   - **Runs**: Latest apply run with resource changes
   - **State**: Current infrastructure state
   - **Variables**: Configured workspace variables
   - **Outputs**: ALB DNS, instance IDs, security groups

---

## Troubleshooting

### Issue: Terraform init fails

**Error**: `Error loading state: AccessDenied`

**Solution**: Verify TFE_TOKEN is set correctly:
```bash
echo $TFE_TOKEN
# Should show your HCP Terraform token

# Re-create credentials file
cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF
```

---

### Issue: Validation fails - Invalid VPC

**Error**: `Error: No default VPC found`

**Solution**: Verify default VPC exists in ap-southeast-2:
```bash
aws ec2 describe-vpcs \
  --filters "Name=is-default,Values=true" \
  --region ap-southeast-2
```

If no default VPC exists, create one:
```bash
aws ec2 create-default-vpc --region ap-southeast-2
```

---

### Issue: EC2 instances unhealthy

**Error**: Target health shows "unhealthy"

**Solution**: Check user data script execution:
```bash
# Get instance ID
INSTANCE_ID=$(terraform output -json ec2_instance_ids | jq -r '.["az-a"]')

# View system log
aws ec2 get-console-output \
  --instance-id $INSTANCE_ID \
  --region ap-southeast-2 \
  --output text
```

Look for errors in nginx installation or firewall configuration.

---

### Issue: HTTPS returns SSL errors

**Error**: `SSL: CERTIFICATE_VERIFY_FAILED`

**Solution**: Verify DNS validation is complete:
```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region ap-southeast-2 \
  | jq -r '.Certificate.Status'
```

If status is not "ISSUED":
1. Verify DNS records are created correctly
2. Wait 5-30 minutes for validation
3. Check DNS propagation: `dig _abc123def456.your-domain.com CNAME`

---

### Issue: ALB returns 503 Service Unavailable

**Error**: HTTP 503 response from ALB

**Solution**: Both instances are unhealthy. Check:
1. Security group rules allow ALB → EC2 on port 80
2. EC2 instances are running
3. Nginx service is active: SSH to instance and run `systemctl status nginx`

---

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Warning**: This will delete:
- Application Load Balancer and listeners
- Target groups
- EC2 instances
- Security groups
- ACM certificate (if DNS validation was not completed)

Type `yes` to confirm destruction.

---

## Next Steps

1. **Custom Domain**: Configure DNS CNAME to point to ALB DNS name
2. **Monitoring**: Set up CloudWatch alarms for target health
3. **Auto Scaling**: Add Auto Scaling Group for dynamic capacity
4. **SSL/TLS**: Update certificate with your actual domain
5. **Content**: Replace static HTML with your application

---

## Useful Commands

```bash
# View all outputs
terraform output

# Get specific output
terraform output alb_dns_name
terraform output acm_certificate_validation_records

# Refresh state
terraform refresh

# Show current state
terraform show

# List all resources
terraform state list

# Format configuration files
terraform fmt -recursive
```

---

## Support

For issues or questions:
- HCP Terraform documentation: https://developer.hashicorp.com/terraform/cloud-docs
- AWS ALB documentation: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/
- Module documentation: HCP Terraform private registry

---

## Summary

This quickstart covered:
1. Prerequisites and setup
2. Variable configuration
3. Terraform initialization and validation
4. Infrastructure deployment
5. ACM DNS validation
6. Application testing
7. Troubleshooting common issues
8. Cleanup procedures

Total deployment time: 15-45 minutes (depending on DNS validation).
