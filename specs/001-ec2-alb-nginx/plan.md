# Implementation Plan: EC2 Infrastructure with ALB and Nginx

**Branch**: `001-ec2-alb-nginx` | **Date**: 2025-12-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/workspace/specs/001-ec2-alb-nginx/spec.md`

## Summary

Deploy a highly available static web infrastructure in AWS consisting of an Application Load Balancer distributing HTTPS traffic across 2 EC2 instances running Nginx in separate availability zones, using private modules from HCP Terraform registry.

**Technical Approach**: Use HCP Terraform private modules (ALB v10.1.0, EC2 v6.1.4, Security Group v5.3.1, ACM v6.1.1) to provision infrastructure in default VPC across 2 AZs with HTTP→HTTPS redirect, health checks, and DNS-validated TLS certificates.

---

## Technical Context

**Language/Version**: Terraform HCL, Terraform ~> 1.5.0, AWS Provider ~> 5.0
**Primary Dependencies**: HCP Terraform private modules (alb, ec2-instance, security-group, acm)
**Storage**: No persistent storage required (stateless web server)
**Testing**: Terraform validate, terraform plan, manual endpoint verification
**Target Platform**: AWS ap-southeast-2, Amazon Linux 2023, t3.micro instances
**Project Type**: Infrastructure (Terraform modules)
**Performance Goals**: Sub-second HTTP response time, 30s health check interval, 60s failover time
**Constraints**: Default VPC only, t3.micro instances, manual DNS validation, no Route53
**Scale/Scope**: 2 EC2 instances, 1 ALB, development environment, minimal cost

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Module-First Architecture ✅

- **Status**: PASS
- **Requirement**: All infrastructure MUST be provisioned through approved modules from Private Module Registry
- **Implementation**:
  - ALB: `app.terraform.io/hashi-demos-apj/alb/aws` v10.1.0
  - EC2: `app.terraform.io/hashi-demos-apj/ec2-instance/aws` v6.1.4
  - Security Group: `app.terraform.io/hashi-demos-apj/security-group/aws` v5.3.1
  - ACM: `app.terraform.io/hashi-demos-apj/acm/aws` v6.1.1
- **Verification**: All modules verified via MCP `get_private_module_details` tool
- **Source Format**: All module sources begin with `app.terraform.io/hashi-demos-apj/`

### Specification-Driven Development ✅

- **Status**: PASS
- **Requirement**: Infrastructure code generation MUST be driven by explicit specifications
- **Implementation**:
  - Feature specification: `/workspace/specs/001-ec2-alb-nginx/spec.md`
  - Research findings: `/workspace/specs/001-ec2-alb-nginx/research.md`
  - Data model: `/workspace/specs/001-ec2-alb-nginx/data-model.md`
  - Module contracts: `/workspace/specs/001-ec2-alb-nginx/contracts/module-interfaces.md`
- **Verification**: All technical decisions documented with rationale
- **Traceability**: Code comments reference FR-XXX requirements from spec

### Security-First Automation ✅

- **Status**: PASS
- **Requirement**: Generated code MUST assume zero trust and implement security controls by default
- **Implementation**:
  - No static credentials in code or variables
  - AWS credentials pre-configured in workspace variable sets
  - Security groups use least privilege (ALB→internet, EC2←ALB only)
  - HTTPS enforced via HTTP→HTTPS redirect
  - TLS termination at ALB with ACM certificate
  - Egress rules explicitly defined (no default allow-all)
- **Documentation**: Security rationale included in code comments

### HCP Terraform Prerequisites ✅

- **Status**: PASS
- **Requirement**: HCP Terraform configuration details MUST be determined before operations
- **Configuration**:
  - Organization: `hashi-demos-apj`
  - Project: `sandbox` (ID: prj-QueMgU3LXgV2Ag7s)
  - Workspace: `sandbox_ec2workspace`
- **Verification**: Configuration provided by user, validated against HCP Terraform

### File Organization ✅

- **Status**: PASS
- **Requirement**: Terraform files MUST follow organizational conventions
- **Structure**:
  ```
  /
  ├── main.tf              # Module instantiations
  ├── variables.tf         # Input variable declarations
  ├── outputs.tf           # Output declarations
  ├── locals.tf            # Terraform locals
  ├── provider.tf          # Provider configuration
  ├── terraform.tf         # Version constraints
  ├── override.tf          # HCP backend for testing
  ├── sandbox.auto.tfvars  # Variable values
  └── README.md            # Documentation
  ```
- **Compliance**: No monolithic files, logical grouping by concern

### Naming Conventions ✅

- **Status**: PASS
- **Requirement**: Names MUST follow HashiCorp naming standards
- **Implementation**:
  - Resources: `<app>-<resource-type>-<purpose>` (e.g., `nginx-az-a`, `ec2-nginx-alb`)
  - Variables: `snake_case` (e.g., `domain_name`, `instance_type`)
  - Modules: `<provider>-<resource>-<purpose>`
- **Verification**: Follows https://developer.hashicorp.com/terraform/plugin/best-practices/naming

### Variable Management ✅

- **Status**: PASS
- **Requirement**: Variables MUST be explicitly declared with comprehensive metadata
- **Implementation**:
  - All variables have `description`, `type`, and `validation` blocks
  - Sensitive variables marked as `sensitive = true`
  - No use of implicit `any` type
  - Workspace variable sets leveraged (AWS credentials)

### Security Best Practices ✅

- **Status**: PASS
- **Requirement**: Generated code must embed security best practices
- **Implementation**:
  - Encryption enabled for data in transit (HTTPS/TLS)
  - Network segmentation via security groups
  - Least privilege access (EC2 only accessible from ALB)
  - No public SSH access
  - Egress rules limited to package downloads (80/443)
- **Documentation**: Security rationale in code comments

### Credential Management ✅

- **Status**: PASS
- **Requirement**: No static credentials SHALL be generated or stored in code
- **Implementation**:
  - AWS provider uses workspace-level dynamic credentials
  - No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` variables
  - ACM certificate uses DNS validation (no email credentials)
- **Verification**: No credential variables in `variables.tf`

### Least Privilege by Default (AWS) ✅

- **Status**: PASS
- **Requirement**: Generated infrastructure MUST implement principle of least privilege
- **Implementation**:
  - ALB SG: Ingress 0.0.0.0/0:80,443 (required for public access), egress only to EC2 SG:80
  - EC2 SG: Ingress only from ALB SG:80, egress to 0.0.0.0/0:80,443 (package management)
  - No wildcard permissions in IAM (not using IAM for this deployment)
  - Public IP only for EC2 internet access (temporary for package downloads)
- **Justification**: Public access required for static website hosting

### Workspace Management ✅

- **Status**: PASS
- **Requirement**: HCP Terraform workspaces are pre-provisioned
- **Implementation**:
  - Workspace `sandbox_ec2workspace` pre-created
  - No workspace creation in code
  - Testing uses Terraform CLI with cloud backend
  - Variables managed via `sandbox.auto.tfvars`
- **Verification**: Workspace exists in organization `hashi-demos-apj`

### Code Quality and Documentation ✅

- **Status**: PASS
- **Requirement**: AI-generated code MUST be self-documenting with external documentation
- **Implementation**:
  - Comprehensive README.md with deployment instructions
  - All variables and outputs have descriptions
  - Inline comments for non-obvious configurations
  - quickstart.md for step-by-step deployment
- **Automation**: `terraform-docs` compatible structure

### Version Control ✅

- **Status**: PASS
- **Requirement**: Generated code MUST be version controlled with meaningful commits
- **Implementation**:
  - Feature branch: `001-ec2-alb-nginx`
  - Atomic commits per logical change
  - No secrets, credentials, or sensitive data in commits
  - `.gitignore` for state files and credentials

### State Management ✅

- **Status**: PASS
- **Requirement**: All state MUST be managed remotely in HCP Terraform
- **Implementation**:
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
- **Verification**: No local backend configuration

### Dependency Management ✅

- **Status**: PASS
- **Requirement**: Provider and module versions MUST be explicitly constrained
- **Implementation**:
  - Module versions: Exact versions (10.1.0, 6.1.4, 5.3.1, 6.1.1)
  - AWS provider: `~> 5.0` (pessimistic constraint)
  - Terraform: `>= 1.5.0`
- **Rationale**: Exact module versions ensure consistency

---

## Post-Design Constitution Re-check

All constitution requirements remain PASS after Phase 1 design completion. No violations or exceptions required.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-ec2-alb-nginx/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - Technical decisions
├── data-model.md        # Phase 1 output - Resource relationships
├── quickstart.md        # Phase 1 output - Deployment guide
├── contracts/           # Phase 1 output - Module interfaces
│   └── module-interfaces.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT YET CREATED)
```

### Source Code (repository root)

```text
/
├── main.tf              # Module declarations (ALB, EC2, SG, ACM)
├── variables.tf         # Input variables (domain_name, region, etc.)
├── outputs.tf           # Outputs (alb_dns_name, instance_ids, etc.)
├── locals.tf            # Local values (subnets, instances, tags)
├── provider.tf          # AWS provider configuration
├── terraform.tf         # Terraform version and provider constraints
├── override.tf          # HCP Terraform backend (sandbox workspace)
├── sandbox.auto.tfvars  # Variable values for sandbox deployment
├── user-data.sh         # User data script for EC2 Nginx installation
└── README.md            # Comprehensive deployment documentation
```

**Structure Decision**: Single project structure selected (Option 1 from template). This is an infrastructure-only project with no application code, backend, or frontend components. All Terraform configuration resides in the repository root with supporting scripts in dedicated files.

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Region: ap-southeast-2           │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │              Default VPC (172.31.0.0/16)          │ │
│  │                                                   │ │
│  │  ┌─────────────────────────────────────────────┐ │ │
│  │  │      Application Load Balancer              │ │ │
│  │  │  ┌──────────┐        ┌──────────┐          │ │ │
│  │  │  │ HTTP:80  │───────▶│HTTPS:443 │          │ │ │
│  │  │  │ Redirect │        │ Forward  │          │ │ │
│  │  │  └──────────┘        └────┬─────┘          │ │ │
│  │  │                           │                 │ │ │
│  │  │  ┌────────────────────────▼───────────┐    │ │ │
│  │  │  │   Target Group (HTTP:80)           │    │ │ │
│  │  │  │   Health: 30s interval, 2 checks   │    │ │ │
│  │  │  └───┬──────────────────────┬─────────┘    │ │ │
│  │  └──────┼──────────────────────┼──────────────┘ │ │
│  │         │                      │                │ │
│  │  ┌──────▼────────┐      ┌─────▼──────────┐     │ │
│  │  │ AZ-A          │      │ AZ-B           │     │ │
│  │  │ ┌──────────┐  │      │ ┌──────────┐  │     │ │
│  │  │ │EC2       │  │      │ │EC2       │  │     │ │
│  │  │ │nginx-az-a│  │      │ │nginx-az-b│  │     │ │
│  │  │ │t3.micro  │  │      │ │t3.micro  │  │     │ │
│  │  │ │Nginx:80  │  │      │ │Nginx:80  │  │     │ │
│  │  │ └──────────┘  │      │ └──────────┘  │     │ │
│  │  └───────────────┘      └────────────────┘     │ │
│  │                                                 │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │  Security Groups                                │ │
│  │  ┌───────────┐       ┌───────────┐             │ │
│  │  │  ALB SG   │──────▶│  EC2 SG   │             │ │
│  │  │  In:80,443│       │  In:80    │             │ │
│  │  │  Out:80   │       │  Out:80,  │             │ │
│  │  │           │       │      443  │             │ │
│  │  └───────────┘       └───────────┘             │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘

┌──────────────────────┐
│  ACM Certificate     │
│  DNS Validation      │
│  (Manual)            │
└─────────┬────────────┘
          │
          ▼
   ALB HTTPS Listener
```

### Module Dependencies

```
Phase 1: Data Discovery
├── aws_vpc.default
├── aws_subnets.default
└── aws_ssm_parameter.amazon_linux_2023

Phase 2: Security Groups
├── module.alb_sg
└── module.ec2_sg (depends on alb_sg)

Phase 3: Certificates
└── module.acm

Phase 4: Compute
└── module.ec2_instance[*] (depends on ec2_sg)

Phase 5: Load Balancer
└── module.alb (depends on alb_sg, ec2_instance, acm)
```

---

## Implementation Sequence

### Phase 0: Research (✅ COMPLETE)

**Deliverable**: `/workspace/specs/001-ec2-alb-nginx/research.md`

Key research completed:
1. AMI Selection: Amazon Linux 2023 via SSM parameter
2. VPC Discovery: Data source for default VPC and subnets
3. User Data Script: Bash with dnf package manager
4. Health Check Configuration: HTTP:80 / with 30s interval
5. ACM DNS Validation: Manual DNS record creation
6. Security Group Architecture: Two-layer with reference-based rules
7. EC2 Deployment Pattern: for_each with map configuration
8. ALB Listener Configuration: HTTP redirect + HTTPS forward
9. Target Group Configuration: Instance targets with health checks
10. Resource Tagging: Consistent tags for cost allocation
11. Module Version Strategy: Exact versions for reproducibility
12. HCP Terraform Configuration: Cloud block for remote execution

---

### Phase 1: Design & Contracts (✅ COMPLETE)

**Deliverable**: `/workspace/specs/001-ec2-alb-nginx/data-model.md`, `/workspace/specs/001-ec2-alb-nginx/contracts/`, `/workspace/specs/001-ec2-alb-nginx/quickstart.md`

Artifacts created:
1. **data-model.md**: Entity definitions, relationships, network topology
2. **contracts/module-interfaces.md**: Module inputs/outputs, integration dependencies
3. **quickstart.md**: Step-by-step deployment instructions

Key design decisions:
- Data sources for dynamic resource discovery (VPC, subnets, AMI)
- Module input/output mappings documented
- Security group rule definitions finalized
- Network topology with traffic flow diagrams
- Variable definitions with validation rules
- Output definitions for downstream consumption

---

### Phase 2: Task Generation (PENDING)

**Command**: `/speckit.tasks`

**Deliverable**: `/workspace/specs/001-ec2-alb-nginx/tasks.md`

Expected tasks (to be generated):
1. Create Terraform configuration files (main.tf, variables.tf, outputs.tf, locals.tf)
2. Create provider configuration (provider.tf, terraform.tf)
3. Create HCP backend configuration (override.tf)
4. Create user data script (user-data.sh)
5. Create variable values file (sandbox.auto.tfvars)
6. Create README.md with deployment documentation
7. Run terraform init and validate
8. Run terraform plan for verification
9. Commit and push to feature branch
10. Deploy to sandbox workspace for testing

---

### Phase 3: Implementation (PENDING)

**Command**: `/speckit.implement`

**Deliverable**: Working Terraform configuration, deployed infrastructure

Implementation steps:
1. Generate all Terraform files from templates
2. Validate configuration syntax
3. Initialize Terraform with HCP backend
4. Plan infrastructure changes
5. Review plan output for correctness
6. Apply configuration to sandbox workspace
7. Verify ACM DNS validation records
8. Test HTTP→HTTPS redirect
9. Test load balancing across instances
10. Document deployment outputs

---

## Security Considerations

### Network Security

1. **Security Group Isolation**:
   - ALB: Public ingress (80/443), egress only to EC2 SG
   - EC2: Ingress only from ALB SG, egress for package downloads
   - No SSH access configured (use AWS Systems Manager Session Manager if needed)

2. **TLS/SSL Encryption**:
   - ACM-managed certificate with automatic renewal
   - TLS 1.2+ enforced at ALB
   - HTTP traffic automatically redirected to HTTPS

3. **Least Privilege**:
   - EC2 instances not directly accessible from internet
   - Security groups reference each other (no IP-based rules)
   - Egress limited to necessary ports (80/443 for package management)

### Application Security

1. **Static Content Only**:
   - No dynamic code execution
   - No database connections
   - Minimal attack surface

2. **Health Checks**:
   - Automatic detection of unhealthy instances
   - Traffic routed only to healthy targets
   - 2 consecutive checks for status changes

3. **Instance Hardening**:
   - Latest Amazon Linux 2023 AMI
   - Firewalld configured for HTTP only
   - Systemd service management

---

## Testing Strategy

### Pre-Deployment Testing

1. **Terraform Validation**:
   ```bash
   terraform init
   terraform validate
   terraform fmt -check
   ```

2. **Plan Review**:
   ```bash
   terraform plan
   # Review: 15 resources to add
   # Verify: No destructive changes
   ```

3. **Module Verification**:
   - All modules from private registry
   - Exact version constraints
   - Module outputs match expected schema

### Post-Deployment Testing

1. **Infrastructure Validation**:
   ```bash
   # Verify ALB DNS endpoint
   terraform output alb_dns_name

   # Check target health
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn)
   ```

2. **Application Testing**:
   ```bash
   # Test HTTP redirect
   curl -I http://<alb-dns-name>
   # Expected: 301 redirect to HTTPS

   # Test HTTPS (after DNS validation)
   curl https://<alb-dns-name>
   # Expected: HTML with server hostname
   ```

3. **High Availability Testing**:
   ```bash
   # Multiple requests to verify load balancing
   for i in {1..10}; do
     curl -s https://<alb-dns-name> | grep "Server:"
   done
   # Expected: Alternating server hostnames
   ```

4. **Security Testing**:
   ```bash
   # Verify EC2 not directly accessible
   curl http://<ec2-public-ip>
   # Expected: Timeout (security group blocks)

   # Verify HTTPS certificate
   openssl s_client -connect <alb-dns-name>:443
   # Expected: Valid certificate chain
   ```

### Manual Validation Checklist

- [ ] Default VPC exists in ap-southeast-2
- [ ] At least 2 subnets in different AZs
- [ ] AWS credentials configured in HCP workspace
- [ ] Domain name provided for ACM certificate
- [ ] DNS provider access for validation records
- [ ] Terraform plan shows 15 resources to add
- [ ] All module sources begin with `app.terraform.io/hashi-demos-apj/`
- [ ] No hardcoded credentials in code
- [ ] Security groups reference each other correctly
- [ ] Health checks configured correctly (30s, 2 checks)
- [ ] HTTP redirects to HTTPS (301)
- [ ] Both EC2 instances healthy in target group
- [ ] Load balancing works (alternating servers)
- [ ] ACM DNS validation records documented

---

## Cost Estimation

### Monthly Cost (Development Environment)

| Resource | Type | Quantity | Unit Cost | Monthly Cost |
|----------|------|----------|-----------|--------------|
| EC2 Instances | t3.micro | 2 | $7.50/mo | $15.00 |
| ALB | Application | 1 | $16.20/mo | $16.20 |
| Data Transfer | Minimal | <1GB | $0.09/GB | $0.10 |
| **Total** | | | | **~$31.30** |

**Assumptions**:
- EC2 instances running 24/7
- ALB with minimal traffic (<1GB/month)
- ACM certificate: Free
- No additional EBS volumes beyond root
- Free tier not applied

**Cost Optimization**:
- Use t3.micro (smallest burstable instance)
- Single ALB serving both instances
- Default VPC (no VPC costs)
- Development environment tags for cost tracking

---

## Deployment Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Environment Setup | 5 min | HCP Terraform access, AWS credentials |
| Terraform Init | 2 min | Module downloads |
| Terraform Plan | 3 min | Validation, planning |
| Terraform Apply | 8 min | Resource creation |
| **ACM DNS Validation** | **5-30 min** | **Manual DNS record creation** |
| Application Testing | 5 min | Validation complete |
| **Total** | **28-53 min** | |

**Critical Path**: ACM DNS validation is the longest variable step (5-30 minutes depending on DNS propagation).

---

## Complexity Tracking

No complexity violations. All constitution requirements met without exceptions.

| Requirement | Status | Justification |
|-------------|--------|---------------|
| Module-First Architecture | ✅ PASS | All infrastructure via private modules |
| Security-First | ✅ PASS | Multi-layer security, HTTPS enforced |
| Specification-Driven | ✅ PASS | Complete spec, research, data model |
| No Static Credentials | ✅ PASS | Workspace-level dynamic credentials |
| Least Privilege | ✅ PASS | Security groups with minimal access |

---

## Risk Assessment

### High Risk

**Risk**: ACM DNS validation failure
- **Impact**: HTTPS listener non-functional
- **Probability**: Medium (manual process)
- **Mitigation**:
  - Detailed validation instructions in quickstart.md
  - Fallback to HTTP-only for testing
  - Clear error messages in outputs

### Medium Risk

**Risk**: Default VPC not available
- **Impact**: Deployment failure
- **Probability**: Low (default VPC standard)
- **Mitigation**:
  - Pre-deployment validation script
  - Clear error messages
  - Instructions to create default VPC

### Low Risk

**Risk**: Instance type unavailable in AZ
- **Impact**: EC2 launch failure
- **Probability**: Very Low (t3.micro widely available)
- **Mitigation**:
  - Use common instance type
  - Multiple AZ selection

**Risk**: Health check failures
- **Impact**: Instances marked unhealthy
- **Probability**: Low (simple static content)
- **Mitigation**:
  - Comprehensive user data script
  - Health check troubleshooting guide
  - System log access instructions

---

## Success Criteria

Implementation is successful when:

1. ✅ All 15 Terraform resources created without errors
2. ✅ Both EC2 instances show "healthy" in target group
3. ✅ HTTP requests redirect to HTTPS (301 status)
4. ✅ HTTPS requests return HTML content (200 status)
5. ✅ Load balancing distributes across both instances
6. ✅ Response time < 1 second for static content
7. ✅ ACM certificate status is "ISSUED"
8. ✅ Security groups allow only required traffic
9. ✅ All resources tagged correctly
10. ✅ HCP Terraform state reflects actual infrastructure

---

## Next Steps

1. **Execute `/speckit.tasks`** to generate task breakdown
2. **Review tasks.md** for implementation steps
3. **Execute `/speckit.implement`** to generate Terraform code
4. **Deploy to sandbox workspace** for validation
5. **Complete ACM DNS validation** manually
6. **Test all acceptance scenarios** from spec.md
7. **Document lessons learned** for future deployments

---

## References

- Feature Specification: `/workspace/specs/001-ec2-alb-nginx/spec.md`
- Research Findings: `/workspace/specs/001-ec2-alb-nginx/research.md`
- Data Model: `/workspace/specs/001-ec2-alb-nginx/data-model.md`
- Module Contracts: `/workspace/specs/001-ec2-alb-nginx/contracts/module-interfaces.md`
- Quickstart Guide: `/workspace/specs/001-ec2-alb-nginx/quickstart.md`
- HCP Terraform Docs: https://developer.hashicorp.com/terraform/cloud-docs
- AWS ALB Docs: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/
- Terraform Constitution: `/workspace/.specify/memory/constitution.md`

---

**Plan Status**: Phase 0 and Phase 1 complete. Ready for Phase 2 (Task Generation).
