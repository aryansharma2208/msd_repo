variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "hello-service"
}

variable "instance_type" {
  description = "EC2 instance type. Must be marked 'Free tier eligible' for your account."
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.10/32). Only this range can reach SSH."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a valid CIDR such as 203.0.113.10/32 and must not be 0.0.0.0/0."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for admin access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
