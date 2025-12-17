# Feature Specification: EC2 Infrastructure with ALB and Nginx

**Feature Branch**: `001-ec2-alb-nginx`
**Created**: 2025-12-17
**Status**: Draft
**Input**: User description: "Provision EC2 infrastructure with ALB and Nginx for a static content page in AWS."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Static Content Delivery (Priority: P1)

As a DevOps engineer, I need to provision a highly available static content infrastructure in AWS that serves a simple HTML page over HTTPS to validate the baseline infrastructure setup.

**Why this priority**: This is the core functionality that proves the infrastructure is working end-to-end. Without this, no other features matter. It establishes the foundation for all subsequent capabilities.

**Independent Test**: Can be fully tested by accessing the ALB DNS endpoint via HTTPS and verifying that the static HTML page loads successfully from both availability zones. Delivers a working, publicly accessible static website.

**Acceptance Scenarios**:

1. **Given** the infrastructure is provisioned, **When** a user accesses the ALB endpoint via HTTPS, **Then** they should see the static HTML page with a 200 OK response
2. **Given** the infrastructure is provisioned, **When** a user accesses the ALB endpoint via HTTP (port 80), **Then** they should be automatically redirected to HTTPS (port 443)
3. **Given** two EC2 instances are running across two availability zones, **When** the ALB receives requests, **Then** traffic should be distributed across both instances
4. **Given** the Nginx service is running on both EC2 instances, **When** health checks are performed, **Then** both instances should report as healthy in the target group

---

### User Story 2 - High Availability and Fault Tolerance (Priority: P2)

As a DevOps engineer, I need the infrastructure to remain available even if one availability zone experiences issues, ensuring continuous service delivery.

**Why this priority**: High availability is critical for production-grade infrastructure but secondary to basic functionality. This validates the multi-AZ architecture and automatic failover capabilities.

**Independent Test**: Can be tested independently by manually stopping the Nginx service on one EC2 instance and verifying that traffic continues to flow through the healthy instance without user-visible errors.

**Acceptance Scenarios**:

1. **Given** both EC2 instances are running, **When** one instance becomes unhealthy, **Then** the ALB should route all traffic to the remaining healthy instance
2. **Given** one instance is marked unhealthy by the ALB, **When** the instance recovers and passes health checks, **Then** the ALB should automatically resume sending traffic to that instance
3. **Given** the infrastructure spans two availability zones, **When** one AZ experiences degradation, **Then** the service should remain accessible through the other AZ

---

### User Story 3 - Secure Communication (Priority: P3)

As a security-conscious engineer, I need all public traffic to be encrypted using HTTPS with valid certificates to protect data in transit.

**Why this priority**: Security is important but can be implemented after basic functionality is validated. For development environments, self-signed certificates provide adequate security for testing purposes.

**Independent Test**: Can be tested independently by verifying the TLS certificate is properly configured on the ALB and that HTTP requests are redirected to HTTPS, ensuring no unencrypted traffic is served.

**Acceptance Scenarios**:

1. **Given** an ACM certificate is provisioned, **When** the ALB listener is configured for HTTPS, **Then** the certificate should be successfully associated with the listener
2. **Given** a user accesses the ALB via HTTP, **When** the request reaches the load balancer, **Then** the user should be redirected to the HTTPS endpoint with a 301 or 302 status code
3. **Given** the ALB is configured with HTTPS, **When** a user inspects the certificate, **Then** the certificate details should be visible and valid for the ALB endpoint

---

### Edge Cases

- What happens when both EC2 instances fail health checks simultaneously? The ALB should return 503 Service Unavailable to clients (expected behavior documented).
- How does the system handle rapid scaling during initial provisioning? The target group waits for 2 consecutive successful health checks (60 seconds minimum) before marking instances as healthy.
- What happens if the ACM certificate fails to provision? Terraform apply fails with error message; deployment guide provides troubleshooting steps for manual DNS validation or HTTP-only fallback configuration.
- How does the system handle default VPC subnet availability? Terraform data source validates at least 2 subnets exist in different AZs; deployment fails with validation error if insufficient subnets available.
- What happens when user_data script fails on an EC2 instance? Health checks fail after 2 consecutive attempts (60 seconds), ALB marks instance unhealthy and stops routing traffic to it.
- What happens if dnf package manager cannot reach repositories during user_data execution? Instance provisioning completes but nginx fails to install, health checks fail, instance marked unhealthy (egress rules to 0.0.0.0/0:80,443 mitigate this).
- What happens during concurrent requests while one instance is unhealthy? ALB immediately routes 100% of traffic to remaining healthy instance without dropped connections.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provision exactly 2 EC2 instances of type t3.micro across 2 different availability zones in ap-southeast-2
- **FR-002**: System MUST use the existing default VPC and its subnets (no new VPC creation)
- **FR-003**: System MUST install and configure Nginx on each EC2 instance to serve a static HTML page displaying "Welcome to EC2 ALB Nginx Infrastructure" with server hostname and timestamp
- **FR-004**: System MUST provision an Application Load Balancer (ALB) to distribute traffic across the EC2 instances
- **FR-005**: System MUST configure ALB listeners for HTTP (port 80) with redirect to HTTPS, and HTTPS (port 443) forwarding to target group
- **FR-006**: System MUST provision an ACM certificate for HTTPS support using DNS validation (manual DNS record creation required) or document HTTP-only fallback option for initial sandbox testing
- **FR-007**: System MUST configure security group for ALB allowing inbound traffic on ports 80 and 443 from the internet (0.0.0.0/0)
- **FR-008**: System MUST configure security group for EC2 instances allowing inbound traffic on port 80 only from the ALB security group
- **FR-009**: System MUST configure target group with health checks using HTTP protocol on port 80 to path `/` with 30-second interval, 5-second timeout, 2 consecutive successes for healthy, 2 consecutive failures for unhealthy
- **FR-010**: System MUST register both EC2 instances with the ALB target group
- **FR-011**: System MUST use private modules from app.terraform.io/hashi-demos-apj registry: alb (v10.1.0), ec2-instance (v6.1.4), security-group (v5.3.1), acm (v6.1.1)
- **FR-012**: System MUST deploy infrastructure to HCP Terraform workspace: sandbox_ec2workspace in project: sandbox, organization: hashi-demos-apj
- **FR-013**: System MUST output the ALB DNS endpoint for user access
- **FR-014**: EC2 instances MUST use user_data bash scripts with dnf package manager to install nginx, enable systemd service, create index.html with hostname/timestamp, and configure firewall for port 80
- **FR-015**: System MUST use latest Amazon Linux 2023 AMI retrieved dynamically via AWS SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
- **FR-016**: System MUST select subnets dynamically from default VPC using Terraform data sources, ensuring 2 subnets from different availability zones
- **FR-017**: System MUST tag all resources with: `environment = "development"`, `project = "ec2-alb-nginx"`, `managed-by = "terraform"`, `workspace = "sandbox_ec2workspace"`
- **FR-018**: ALB MUST have deletion protection DISABLED for development environment to enable rapid iteration
- **FR-019**: Security groups MUST configure egress rules: ALB to EC2 on port 80, EC2 to internet (0.0.0.0/0) on ports 80 and 443 for package management

### Key Entities *(include if feature involves data)*

- **VPC**: The existing default VPC in ap-southeast-2 region, provides network isolation and subnet allocation
- **Subnet**: Default VPC subnets across multiple availability zones, provide network placement for EC2 instances and ALB
- **EC2 Instance**: Small, cost-optimized compute instances with web server software, serve static content
- **Application Load Balancer**: Layer 7 load balancer, distributes HTTP/HTTPS traffic across EC2 instances in multiple AZs
- **Target Group**: Logical grouping of EC2 instances, performs health checks and routes traffic to healthy targets
- **Security Group**: Virtual firewall rules, controls inbound/outbound traffic for ALB and EC2 instances
- **ACM Certificate**: TLS/SSL certificate for HTTPS, enables encrypted communication between clients and ALB
- **Static HTML Page**: Simple HTML content served by Nginx, validates end-to-end infrastructure functionality

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can access the static HTML page via HTTPS within 5 seconds of entering the ALB DNS endpoint in a browser
- **SC-002**: Infrastructure supports concurrent access from at least 100 users without response time degradation
- **SC-003**: ALB successfully redirects 100% of HTTP requests to HTTPS with appropriate status codes
- **SC-004**: System maintains 99% availability when one availability zone or one EC2 instance is unavailable
- **SC-005**: Health checks detect instance failures within 30 seconds and remove unhealthy targets from rotation
- **SC-006**: All infrastructure provisioning completes within 10 minutes from deployment initiation
- **SC-007**: Static HTML page loads with sub-second response time under normal load conditions
- **SC-008**: Infrastructure costs remain under 50 USD per month for development environment (t3.micro instances, minimal ALB usage)

## Clarifications

### Session 2025-12-17

This section documents autonomous best-practice decisions made during the clarification phase to resolve ambiguities in the specification.

- Q: What AMI should EC2 instances use for optimal compatibility and security? → A: Latest Amazon Linux 2023 AMI retrieved dynamically via AWS SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` for automatic security updates and long-term support.

- Q: What specific content should the static HTML page display for testing? → A: Simple HTML page displaying "Welcome to EC2 ALB Nginx Infrastructure" with server hostname and timestamp to validate both load balancing distribution and successful deployment across instances.

- Q: What health check configuration should the target group use? → A: HTTP protocol on port 80 to path `/` with 30-second interval, 5-second timeout, 2 consecutive successes for healthy status, 2 consecutive failures for unhealthy status (AWS defaults for reliable detection).

- Q: How should SSL/TLS be configured given no Route53 zone exists? → A: Use ACM with DNS validation but document manual DNS record creation requirement in deployment guide; alternatively accept HTTP-only for initial sandbox testing to unblock development (HTTPS listener configured but may require manual certificate validation step).

- Q: What user_data script should provision Nginx and content? → A: Bash script using dnf package manager (Amazon Linux 2023): install nginx, enable service, create /usr/share/nginx/html/index.html with hostname/timestamp, configure firewall for port 80.

- Q: How should subnets be selected from default VPC? → A: Use Terraform data source `aws_subnets` with filter for default VPC, then select first 2 subnets from different availability zones dynamically to ensure multi-AZ placement without hardcoding subnet IDs.

- Q: What specific tags should be applied for cost tracking? → A: Standard tags: `environment = "development"`, `project = "ec2-alb-nginx"`, `managed-by = "terraform"`, `workspace = "sandbox_ec2workspace"` for comprehensive resource identification and cost allocation.

- Q: Should ALB have deletion protection enabled? → A: Deletion protection DISABLED for development/sandbox environment to allow rapid iteration and cleanup; would be enabled for production environments.

- Q: What should happen if ACM certificate provisioning fails? → A: Terraform apply should fail with clear error message; deployment guide must include troubleshooting steps for manual DNS validation record creation or temporary HTTP-only fallback configuration.

- Q: What security group egress rules should be configured? → A: ALB security group: egress to EC2 security group on port 80. EC2 security group: egress to 0.0.0.0/0 on ports 80 and 443 (for package downloads during user_data execution and potential future updates).

## Assumptions

- Default VPC exists in ap-southeast-2 region with at least 2 subnets across different availability zones
- AWS credentials are pre-configured in HCP Terraform workspace variables and provide sufficient permissions for EC2, VPC, ELB, and ACM operations
- No Route53 hosted zone is available, therefore ACM certificate will use DNS validation with manual DNS record creation or self-signed approach for development
- Static content requirements are minimal - a single HTML file is sufficient for validation (content: "Welcome to EC2 ALB Nginx Infrastructure" with hostname and timestamp)
- Development environment accepts self-signed or AWS-generated certificates without custom domain requirements, or HTTP-only for initial testing
- Compute instances will use Amazon Linux 2023 with dnf package manager for Nginx installation via user_data bash scripts
- HCP Terraform workspace (sandbox_ec2workspace) already exists with proper permissions
- Internet Gateway is already attached to the default VPC enabling public internet access
- Cost optimization is prioritized over performance (t3.micro instances are adequate for low-traffic static content)
- No auto-scaling is required for this development environment
- Standard AWS health check intervals and thresholds are acceptable (30-second intervals, 5-second timeout, 2 consecutive checks for healthy/unhealthy status transitions)

## Constraints

- MUST use ap-southeast-2 AWS region
- MUST use existing default VPC (no new VPC creation permitted)
- MUST use t3.micro instance type for cost optimization
- MUST use private modules from hashi-demos-apj HCP Terraform registry
- MUST deploy to HCP Terraform organization: hashi-demos-apj, project: sandbox
- MUST NOT exceed development environment budget constraints
- MUST NOT configure cloud provider credentials in workspace variables (pre-configured externally)
- Infrastructure MUST pass terraform validate before deployment

## Dependencies

- Existing default VPC in ap-southeast-2 with Internet Gateway attached and at least 2 subnets across different availability zones
- AWS credentials pre-configured in HCP Terraform with permissions for: EC2 (RunInstances, DescribeInstances), ELB (CreateLoadBalancer, CreateTargetGroup), ACM (RequestCertificate, DescribeCertificate), VPC (DescribeVpcs, DescribeSubnets), Security Groups (CreateSecurityGroup, AuthorizeSecurityGroupIngress, AuthorizeSecurityGroupEgress), SSM (GetParameter for AMI lookup)
- HCP Terraform workspace: sandbox_ec2workspace exists in organization hashi-demos-apj, project sandbox
- Private modules available in HCP Terraform registry: alb v10.1.0, ec2-instance v6.1.4, security-group v5.3.1, acm v6.1.1
- Terraform CLI for local validation and testing
- GitHub repository for version control of Terraform code
- Manual DNS record creation capability if ACM DNS validation is used (or acceptance of HTTP-only for initial testing)

## Out of Scope

- Creation of new VPC or custom networking configurations
- Route53 DNS management and custom domain configuration
- Auto-scaling groups or dynamic capacity management
- CloudWatch alarms or monitoring dashboards
- CloudFront CDN distribution
- WAF (Web Application Firewall) rules
- S3 bucket for static content storage
- CI/CD pipeline integration
- Backup and disaster recovery procedures
- Production-grade certificate validation with custom domains
- Instance hardening beyond basic security group configurations
- Logging aggregation or centralized log management
- Database or persistent storage layer
- Container orchestration (ECS/EKS)
- Multi-region deployment
