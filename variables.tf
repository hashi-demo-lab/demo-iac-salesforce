# Input variable declarations
# Feature: EC2 Infrastructure with ALB and Nginx

variable "domain_name" {
  description = "Domain name for ACM certificate (e.g., example.com or sub.example.com). Optional for HTTP-only deployments."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid DNS domain format (e.g., example.com or sub.example.com)."
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

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[2-4]\\.(nano|micro|small|medium|large)$", var.instance_type))
    error_message = "Instance type must be a valid t2, t3, or t4 burstable instance type."
  }
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
