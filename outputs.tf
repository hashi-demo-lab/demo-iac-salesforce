# Output value declarations
# Feature: EC2 Infrastructure with ALB and Nginx

# Primary Outputs
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

# Instance Outputs
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

# Certificate Outputs (disabled for sandbox HTTP-only testing)
# output "acm_certificate_arn" {
#   description = "ARN of the ACM certificate"
#   value       = module.acm.acm_certificate_arn
# }
#
# output "acm_certificate_validation_records" {
#   description = "DNS validation records for manual creation in your DNS provider"
#   value = {
#     for dvo in module.acm.acm_certificate_domain_validation_options : dvo.domain_name => {
#       name  = dvo.resource_record_name
#       type  = dvo.resource_record_type
#       value = dvo.resource_record_value
#     }
#   }
# }

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb_sg.security_group_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.ec2_sg.security_group_id
}
