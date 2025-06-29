variable "region" {
  description = "default region for provider"
  type        = string
  default     = "us-east-1"
}

variable "domain" {
  description = "domain name"
  type        = string
}

variable "ami" {
  description = "Amazon machine image to use for ec2 instances"
  type        = string
}

variable "instance_type" {
  description = "ec2 instance type"
  type        = string
}

variable "db_user" {
  description = "database username"
  type        = string
}

variable "db_pass" {
  description = "database password"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "deployment environment name"
  type        = string
  default     = "dev"
}
