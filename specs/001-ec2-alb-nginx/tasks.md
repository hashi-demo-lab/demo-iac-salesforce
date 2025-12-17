# Tasks: EC2 Infrastructure with ALB and Nginx

**Feature Branch**: `001-ec2-alb-nginx`
**Created**: 2025-12-17

**Input**: Design documents from `/workspace/specs/001-ec2-alb-nginx/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/module-interfaces.md, research.md

**Organization**: Tasks are grouped by implementation phase and user story to enable dependency-ordered execution and independent testing.

## Format: `- [ ] [ID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no task dependencies)
- **[Story]**: User story label (US1, US2, US3) for user story phase tasks only
- All file paths are absolute from repository root

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create basic Terraform project structure and configuration files

**Dependencies**: None - can start immediately

- [ ] T001 Create Terraform version constraints file at /workspace/terraform.tf
- [ ] T002 Create AWS provider configuration file at /workspace/provider.tf
- [ ] T003 [P] Create HCP Terraform backend configuration at /workspace/override.tf
- [ ] T004 [P] Create variables declarations file at /workspace/variables.tf
- [ ] T005 [P] Create outputs declarations file at /workspace/outputs.tf
- [ ] T006 [P] Create locals configuration file at /workspace/locals.tf
- [ ] T007 [P] Create sandbox variable values file at /workspace/sandbox.auto.tfvars
- [ ] T008 [P] Create .gitignore file at /workspace/.gitignore
- [ ] T009 Initialize Terraform with HCP backend connection
- [ ] T010 Validate Terraform configuration syntax

**Acceptance Criteria**:
- All configuration files exist with proper structure
- `terraform init` completes successfully
- `terraform validate` returns "Success! The configuration is valid."
- Module downloads from private registry complete without errors
- No local backend configuration (remote execution only)

---

## Phase 2: Foundational (Data Sources & Discovery)

**Purpose**: Setup data sources for VPC, subnet, and AMI discovery - BLOCKS all infrastructure creation

**Dependencies**: Phase 1 complete

**⚠️ CRITICAL**: All infrastructure resources depend on these data sources

- [ ] T011 Add data source for default VPC discovery in /workspace/main.tf
- [ ] T012 [P] Add data source for default VPC subnets discovery in /workspace/main.tf
- [ ] T013 [P] Add data source for Amazon Linux 2023 AMI via SSM parameter in /workspace/main.tf
- [ ] T014 Add local values for subnet selection (first 2 from different AZs) in /workspace/locals.tf
- [ ] T015 Add local values for instance map configuration in /workspace/locals.tf
- [ ] T016 Add local values for common resource tags in /workspace/locals.tf
- [ ] T017 Validate data sources with terraform plan

**Acceptance Criteria**:
- VPC data source returns valid default VPC ID
- Subnets data source returns at least 2 subnets from different AZs
- SSM parameter returns valid Amazon Linux 2023 AMI ID
- Local values correctly select 2 subnets
- Instance map contains configurations for az-a and az-b
- Common tags include: environment, project, managed-by, workspace

**Checkpoint**: Foundation ready - infrastructure module implementation can now begin

---

## Phase 3: User Story 1 - Basic Static Content Delivery (Priority: P1) 🎯 MVP

**Goal**: Provision highly available static content infrastructure that serves a simple HTML page over HTTPS to validate baseline infrastructure setup

**Independent Test**: Access ALB DNS endpoint via HTTPS and verify static HTML page loads successfully from both availability zones with load balancing

### Security Groups for User Story 1

**Dependencies**: Phase 2 complete (requires VPC ID)

- [ ] T018 [P] [US1] Create ALB security group module declaration in /workspace/main.tf
- [ ] T019 [P] [US1] Configure ALB security group ingress rules (HTTP:80, HTTPS:443 from 0.0.0.0/0) in /workspace/main.tf
- [ ] T020 [US1] Create EC2 security group module declaration in /workspace/main.tf
- [ ] T021 [US1] Configure EC2 security group ingress rules (HTTP:80 from ALB SG) in /workspace/main.tf
- [ ] T022 [US1] Configure ALB security group egress rules (HTTP:80 to EC2 SG) in /workspace/main.tf
- [ ] T023 [US1] Configure EC2 security group egress rules (HTTP:80, HTTPS:443 to 0.0.0.0/0) in /workspace/main.tf

**Acceptance Criteria**:
- ALB security group allows inbound 80/443 from internet
- EC2 security group allows inbound 80 only from ALB security group
- ALB security group allows outbound 80 to EC2 security group
- EC2 security group allows outbound 80/443 for package downloads
- Security groups reference each other correctly (no circular dependency)

### ACM Certificate for User Story 1

**Dependencies**: Phase 2 complete

- [ ] T024 [P] [US1] Create ACM certificate module declaration in /workspace/main.tf
- [ ] T025 [P] [US1] Configure ACM with DNS validation method in /workspace/main.tf
- [ ] T026 [P] [US1] Set ACM to manual DNS validation (wait_for_validation=false) in /workspace/main.tf
- [ ] T027 [P] [US1] Add ACM certificate ARN output in /workspace/outputs.tf
- [ ] T028 [P] [US1] Add ACM DNS validation records output in /workspace/outputs.tf

**Acceptance Criteria**:
- ACM module uses DNS validation method
- Manual DNS validation configured (no Route53 records)
- Certificate ARN available for ALB listener
- DNS validation records available in outputs for manual creation

### EC2 Instances for User Story 1

**Dependencies**: T020-T023 complete (requires EC2 security group)

- [ ] T029 [US1] Create user data script file at /workspace/user-data.sh
- [ ] T030 [US1] Configure user data script to install nginx via dnf in /workspace/user-data.sh
- [ ] T031 [US1] Configure user data script to create HTML page with hostname/timestamp in /workspace/user-data.sh
- [ ] T032 [US1] Configure user data script to enable nginx systemd service in /workspace/user-data.sh
- [ ] T033 [US1] Configure user data script to set firewall rules for HTTP in /workspace/user-data.sh
- [ ] T034 [US1] Create EC2 instance module declaration with for_each in /workspace/main.tf
- [ ] T035 [US1] Configure EC2 instances with t3.micro instance type in /workspace/main.tf
- [ ] T036 [US1] Configure EC2 instances with Amazon Linux 2023 AMI in /workspace/main.tf
- [ ] T037 [US1] Configure EC2 instances with subnet assignments per AZ in /workspace/main.tf
- [ ] T038 [US1] Configure EC2 instances with security group assignment in /workspace/main.tf
- [ ] T039 [US1] Configure EC2 instances with user data script in /workspace/main.tf
- [ ] T040 [US1] Configure EC2 instances with public IP assignment in /workspace/main.tf
- [ ] T041 [US1] Add EC2 instance ID outputs in /workspace/outputs.tf
- [ ] T042 [US1] Add EC2 instance private IP outputs in /workspace/outputs.tf
- [ ] T043 [US1] Add EC2 instance public IP outputs in /workspace/outputs.tf

**Acceptance Criteria**:
- User data script installs nginx using dnf package manager
- User data script creates index.html with "Welcome to EC2 ALB Nginx Infrastructure"
- User data script includes server hostname and timestamp in HTML
- User data script enables and starts nginx via systemd
- User data script configures firewalld for HTTP
- EC2 module creates 2 instances (nginx-az-a, nginx-az-b)
- Each instance placed in different availability zone
- Instances use t3.micro instance type
- Instances assigned EC2 security group
- Instances have public IP for internet access
- Instance outputs available for target group attachment

### Application Load Balancer for User Story 1

**Dependencies**: T018-T023 (ALB security group), T024-T028 (ACM certificate), T034-T043 (EC2 instances)

- [ ] T044 [US1] Create ALB module declaration in /workspace/main.tf
- [ ] T045 [US1] Configure ALB with application load balancer type in /workspace/main.tf
- [ ] T046 [US1] Configure ALB with internet-facing scheme in /workspace/main.tf
- [ ] T047 [US1] Configure ALB with multi-AZ subnet assignment in /workspace/main.tf
- [ ] T048 [US1] Configure ALB with security group assignment in /workspace/main.tf
- [ ] T049 [US1] Configure ALB with deletion protection disabled in /workspace/main.tf
- [ ] T050 [US1] Configure ALB HTTP listener (port 80) with redirect to HTTPS in /workspace/main.tf
- [ ] T051 [US1] Configure ALB HTTPS listener (port 443) with ACM certificate in /workspace/main.tf
- [ ] T052 [US1] Configure ALB HTTPS listener to forward to target group in /workspace/main.tf
- [ ] T053 [US1] Configure target group with HTTP protocol on port 80 in /workspace/main.tf
- [ ] T054 [US1] Configure target group with instance target type in /workspace/main.tf
- [ ] T055 [US1] Configure target group health check (HTTP:80, path /, 30s interval) in /workspace/main.tf
- [ ] T056 [US1] Configure target group health check thresholds (2 healthy, 2 unhealthy) in /workspace/main.tf
- [ ] T057 [US1] Configure target group health check timeout (5 seconds) in /workspace/main.tf
- [ ] T058 [US1] Configure target group health check matcher (HTTP 200) in /workspace/main.tf
- [ ] T059 [US1] Configure target group attachments for both EC2 instances in /workspace/main.tf
- [ ] T060 [US1] Add ALB DNS name output in /workspace/outputs.tf
- [ ] T061 [US1] Add ALB ARN output in /workspace/outputs.tf
- [ ] T062 [US1] Add target group ARN output in /workspace/outputs.tf
- [ ] T063 [US1] Add ALB security group ID output in /workspace/outputs.tf
- [ ] T064 [US1] Add EC2 security group ID output in /workspace/outputs.tf

**Acceptance Criteria**:
- ALB created as application load balancer (not network)
- ALB deployed across 2 availability zones
- ALB assigned ALB security group
- Deletion protection disabled for development environment
- HTTP listener redirects to HTTPS with 301 status code
- HTTPS listener uses ACM certificate ARN
- HTTPS listener forwards traffic to EC2 target group
- Target group uses HTTP protocol on port 80
- Target group configured for instance targets
- Health check uses HTTP:80 with path /
- Health check interval set to 30 seconds
- Health check requires 2 consecutive successes for healthy status
- Health check requires 2 consecutive failures for unhealthy status
- Health check timeout set to 5 seconds
- Health check expects HTTP 200 response
- Both EC2 instances attached to target group
- ALB DNS name available in outputs (primary access point)

### Validation for User Story 1

**Dependencies**: T044-T064 complete (all infrastructure)

- [ ] T065 [US1] Run terraform plan and verify 15+ resources to be created
- [ ] T066 [US1] Review terraform plan output for correctness
- [ ] T067 [US1] Verify all module sources use private registry (app.terraform.io/hashi-demos-apj/)
- [ ] T068 [US1] Verify no hardcoded credentials in configuration
- [ ] T069 [US1] Verify security group rules follow least privilege
- [ ] T070 [US1] Run terraform apply to deploy infrastructure
- [ ] T071 [US1] Wait for EC2 instances to complete user data execution (5 minutes)
- [ ] T072 [US1] Verify target group shows 2 healthy instances
- [ ] T073 [US1] Test HTTP request redirects to HTTPS (301 status code)
- [ ] T074 [US1] Document ACM DNS validation records from outputs
- [ ] T075 [US1] Create manual DNS validation records in DNS provider
- [ ] T076 [US1] Wait for ACM certificate validation to complete (5-30 minutes)
- [ ] T077 [US1] Test HTTPS request returns static HTML page (200 status code)
- [ ] T078 [US1] Verify HTML content displays "Welcome to EC2 ALB Nginx Infrastructure"
- [ ] T079 [US1] Verify HTML content includes server hostname
- [ ] T080 [US1] Verify HTML content includes timestamp
- [ ] T081 [US1] Test multiple HTTPS requests to verify load balancing (alternating hostnames)
- [ ] T082 [US1] Verify response time is under 1 second

**Acceptance Criteria**:
- Terraform plan shows expected number of resources
- All modules sourced from private registry
- No credentials visible in code
- Security groups implement least privilege
- Infrastructure deployed without errors
- Both instances healthy in target group
- HTTP redirects to HTTPS correctly
- DNS validation records documented
- HTTPS returns 200 OK after certificate validation
- Static HTML page displays correct content
- Load balancing distributes across both instances
- Sub-second response time achieved

**Checkpoint**: User Story 1 complete - Basic static content delivery working end-to-end with HTTPS

---

## Phase 4: User Story 2 - High Availability and Fault Tolerance (Priority: P2)

**Goal**: Ensure infrastructure remains available even if one availability zone experiences issues, ensuring continuous service delivery

**Independent Test**: Manually stop nginx service on one EC2 instance and verify traffic continues to flow through healthy instance without user-visible errors

### Testing for User Story 2

**Dependencies**: Phase 3 complete (User Story 1 fully functional)

- [ ] T083 [US2] Identify one EC2 instance for failure simulation
- [ ] T084 [US2] Stop nginx service on selected instance via AWS Systems Manager Session Manager
- [ ] T085 [US2] Wait for health check to detect unhealthy instance (60 seconds)
- [ ] T086 [US2] Verify target group shows 1 healthy, 1 unhealthy instance
- [ ] T087 [US2] Test HTTPS requests continue to succeed (200 status code)
- [ ] T088 [US2] Verify all traffic routed to single healthy instance
- [ ] T089 [US2] Verify no 503 Service Unavailable errors during failover
- [ ] T090 [US2] Start nginx service on failed instance
- [ ] T091 [US2] Wait for health check to detect recovered instance (60 seconds)
- [ ] T092 [US2] Verify target group shows 2 healthy instances
- [ ] T093 [US2] Test load balancing resumes across both instances

**Acceptance Criteria**:
- ALB detects unhealthy instance within 60 seconds
- Traffic routes only to healthy instance automatically
- No user-visible errors during failover
- Service remains accessible with one instance down
- Instance recovery detected within 60 seconds
- Load balancing resumes after recovery
- No manual intervention required for failover

**Checkpoint**: User Story 2 complete - High availability validated with automatic failover

---

## Phase 5: User Story 3 - Secure Communication (Priority: P3)

**Goal**: Ensure all public traffic is encrypted using HTTPS with valid certificates to protect data in transit

**Independent Test**: Verify TLS certificate is properly configured on ALB and HTTP requests are redirected to HTTPS, ensuring no unencrypted traffic is served

### Testing for User Story 3

**Dependencies**: Phase 3 complete (ACM certificate validated and HTTPS working)

- [ ] T094 [US3] Verify ACM certificate status is ISSUED via AWS CLI
- [ ] T095 [US3] Test HTTP request and verify 301 redirect response
- [ ] T096 [US3] Verify redirect Location header points to HTTPS endpoint
- [ ] T097 [US3] Test HTTPS request and verify TLS handshake succeeds
- [ ] T098 [US3] Inspect certificate details via openssl s_client
- [ ] T099 [US3] Verify certificate subject matches ALB domain
- [ ] T100 [US3] Verify certificate validity period is future-dated
- [ ] T101 [US3] Verify certificate chain is complete and valid
- [ ] T102 [US3] Test that HTTP-only access is not possible (always redirects)
- [ ] T103 [US3] Verify TLS protocol version is 1.2 or higher
- [ ] T104 [US3] Verify cipher suite is strong (no weak ciphers)

**Acceptance Criteria**:
- ACM certificate status is ISSUED
- HTTP requests always redirect to HTTPS (301)
- HTTPS requests complete TLS handshake successfully
- Certificate details visible and valid
- Certificate matches ALB endpoint
- Certificate not expired
- Certificate chain validates correctly
- No HTTP-only access possible
- TLS 1.2 or higher enforced
- Strong cipher suites in use

**Checkpoint**: User Story 3 complete - Secure communication validated with HTTPS enforcement

---

## Phase 6: Documentation and Polish

**Purpose**: Complete project documentation and final validation

**Dependencies**: All desired user stories complete

- [ ] T105 [P] Create comprehensive README.md at /workspace/README.md
- [ ] T106 [P] Document deployment instructions in README.md
- [ ] T107 [P] Document variable descriptions in README.md
- [ ] T108 [P] Document output descriptions in README.md
- [ ] T109 [P] Document prerequisites in README.md
- [ ] T110 [P] Document ACM DNS validation process in README.md
- [ ] T111 [P] Document troubleshooting common issues in README.md
- [ ] T112 [P] Document cost estimation in README.md
- [ ] T113 [P] Document security considerations in README.md
- [ ] T114 [P] Document cleanup instructions in README.md
- [ ] T115 Run terraform fmt to format all configuration files
- [ ] T116 Verify terraform validate passes
- [ ] T117 Review all outputs match documented values
- [ ] T118 Verify all resources tagged correctly
- [ ] T119 Run complete end-to-end test from quickstart.md
- [ ] T120 Commit all changes to feature branch
- [ ] T121 Push feature branch to remote repository

**Acceptance Criteria**:
- README.md contains comprehensive deployment guide
- All variables documented with descriptions
- All outputs documented with descriptions
- Prerequisites clearly listed
- DNS validation process documented step-by-step
- Troubleshooting guide covers common errors
- Cost estimation provided for development environment
- Security considerations documented
- Cleanup instructions provided
- All Terraform files properly formatted
- Validation passes without errors
- Outputs match documentation
- All resources have required tags
- End-to-end test succeeds
- Code committed and pushed to repository

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup
  ↓
Phase 2: Foundational (Data Sources)
  ↓
Phase 3: User Story 1 (Basic Static Content) ← MVP STOPS HERE
  ↓
Phase 4: User Story 2 (High Availability) - TESTING ONLY
  ↓
Phase 5: User Story 3 (Secure Communication) - TESTING/VALIDATION ONLY
  ↓
Phase 6: Documentation and Polish
```

### Critical Path

1. **Setup (T001-T010)**: Sequential execution, checkpoint at T010
2. **Foundational (T011-T017)**: Parallel opportunities at T012-T013, checkpoint at T017
3. **User Story 1**:
   - Security Groups (T018-T023): T018-T019 parallel, then T020-T023 sequential
   - ACM Certificate (T024-T028): All parallel
   - EC2 Instances (T029-T043): T029-T033 sequential, T034-T040 related, T041-T043 parallel
   - ALB (T044-T064): T044-T049 sequential, T050-T059 related, T060-T064 parallel
   - Validation (T065-T082): Sequential execution with wait times
4. **User Story 2 (T083-T093)**: Sequential testing with wait times
5. **User Story 3 (T094-T104)**: Sequential testing/validation
6. **Documentation (T105-T121)**: T105-T114 parallel, T115-T121 sequential

### User Story Dependencies

- **User Story 1**: Depends on Foundational phase - No dependencies on other stories
- **User Story 2**: Depends on User Story 1 complete - Tests existing infrastructure
- **User Story 3**: Depends on User Story 1 complete - Validates existing security configuration

### Parallel Opportunities

**Phase 1 (Setup)**:
- T003, T004, T005, T006, T007, T008 can run in parallel

**Phase 2 (Foundational)**:
- T012, T013 can run in parallel

**Phase 3 (User Story 1)**:
- T018, T019 can run in parallel (ALB SG ingress)
- T024, T025, T026, T027, T028 can run in parallel (ACM module)
- T041, T042, T043 can run in parallel (EC2 outputs)
- T060-T064 can run in parallel (ALB outputs)

**Phase 6 (Documentation)**:
- T105-T114 can all run in parallel (different documentation sections)

---

## Implementation Strategy

### MVP First (Recommended)

**Scope**: User Story 1 only - Basic static content delivery

**Steps**:
1. Complete Phase 1: Setup (T001-T010)
2. Complete Phase 2: Foundational (T011-T017)
3. Complete Phase 3: User Story 1 (T018-T082)
4. **STOP and VALIDATE**: Full end-to-end testing
5. Deploy to sandbox workspace
6. Demo to stakeholders

**Outcome**: Working HTTPS static website with load balancing (15+ resources deployed)

**Estimated Time**: 2-3 hours (including DNS validation wait time)

### Incremental Delivery

**Iteration 1**: MVP (User Story 1)
- Deliverable: Static website accessible via HTTPS
- Test: Access ALB endpoint, verify HTML loads from both instances

**Iteration 2**: High Availability (User Story 2)
- Deliverable: Fault-tolerant infrastructure validated
- Test: Simulate instance failure, verify automatic failover

**Iteration 3**: Security Validation (User Story 3)
- Deliverable: TLS/SSL configuration validated
- Test: Verify encryption, certificate validity, redirect behavior

**Iteration 4**: Documentation Complete (Phase 6)
- Deliverable: Production-ready documentation
- Test: New user can deploy following README

### Parallel Team Strategy

**Not Applicable**: This is an infrastructure project where resources have strict dependencies. Sequential execution within each phase is required.

**However**: Documentation (Phase 6) can be written in parallel with testing phases if team capacity allows.

---

## Terraform-Specific Execution Notes

### Manual Steps Required

1. **DNS Validation (T074-T076)**: Manual CNAME record creation in DNS provider
2. **Instance Failure Testing (T084, T090)**: Manual service stop/start via SSM
3. **Certificate Inspection (T098)**: Manual openssl command execution

### Wait Times

- **T071**: 5 minutes for user data script execution
- **T076**: 5-30 minutes for ACM DNS validation
- **T085**: 60 seconds for unhealthy detection
- **T091**: 60 seconds for healthy detection

### HCP Terraform Execution

All `terraform plan` and `terraform apply` commands execute remotely in HCP Terraform workspace `sandbox_ec2workspace`. Local CLI commands trigger remote execution.

### State Management

- Remote state stored in HCP Terraform
- No local state files
- State locking automatic via HCP Terraform

---

## Task Summary

**Total Tasks**: 121

**By Phase**:
- Phase 1 (Setup): 10 tasks
- Phase 2 (Foundational): 7 tasks
- Phase 3 (User Story 1): 65 tasks
- Phase 4 (User Story 2): 11 tasks
- Phase 5 (User Story 3): 11 tasks
- Phase 6 (Documentation): 17 tasks

**By Category**:
- Setup/Configuration: 23 tasks
- Infrastructure Code: 47 tasks
- Testing/Validation: 34 tasks
- Documentation: 17 tasks

**Parallelizable Tasks**: 20 tasks marked with [P]

**User Stories**:
- US1 (P1): 65 tasks - Basic static content delivery
- US2 (P2): 11 tasks - High availability testing
- US3 (P3): 11 tasks - Security validation

**MVP Scope**: Phases 1-3 (82 tasks)

**Estimated Total Effort**: 6-8 hours (including wait times for DNS validation)

---

## Validation Checklist

Before marking implementation complete, verify:

- [ ] All 15+ Terraform resources created successfully
- [ ] Both EC2 instances healthy in target group
- [ ] HTTP redirects to HTTPS (301 status)
- [ ] HTTPS returns static HTML page (200 status)
- [ ] Load balancing works (alternating server hostnames)
- [ ] ACM certificate status is ISSUED
- [ ] Health checks detect instance failures within 60 seconds
- [ ] Traffic continues during single instance failure
- [ ] Instance recovery automatic and detected
- [ ] TLS certificate valid and properly configured
- [ ] All resources tagged correctly
- [ ] No hardcoded credentials in code
- [ ] Security groups follow least privilege
- [ ] Documentation complete and accurate
- [ ] End-to-end test from quickstart.md succeeds

---

## Success Metrics

**User Story 1** (Basic Static Content Delivery):
- ✅ Users can access static HTML page via HTTPS
- ✅ Response time under 1 second
- ✅ HTTP requests redirect to HTTPS
- ✅ Both instances serve traffic

**User Story 2** (High Availability):
- ✅ Service remains available with one instance down
- ✅ Failover occurs within 60 seconds
- ✅ No user-visible errors during failover
- ✅ Automatic recovery when instance restored

**User Story 3** (Secure Communication):
- ✅ ACM certificate properly configured
- ✅ HTTP traffic always redirected to HTTPS
- ✅ TLS 1.2+ enforced
- ✅ Valid certificate chain

**Overall**:
- ✅ Infrastructure deployed in under 10 minutes (excluding DNS validation)
- ✅ All resources created via private modules
- ✅ Cost under $50/month for development environment
- ✅ 99% availability with multi-AZ deployment
