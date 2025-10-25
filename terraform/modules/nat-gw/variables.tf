variable "project_name" {
  description = "Project prefix used in resource names/tags."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where NAT gateways will be created."
  type        = string
}

variable "igw_id" {
  description = "Internet Gateway ID that NAT gateways depend on."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for deploying NAT gateways."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for route table associations."
  type        = list(string)
}