variable "project_name" {
  description = "Project prefix used in resource names/tags."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where NAT gateways will be created."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for deploying NAT gateways."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_ids) > 0
    error_message = "At least one public subnet ID is required to deploy NAT gateways."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for route table associations."
  type        = list(string)
}
