##########
# Data
##########
data "aws_availability_zones" "this" {
  state = "available"
}

locals {
  # Pick AZs for each subnet list; if caller passes more subnets than AZs, we wrap around.
  public_azs  = [for i in range(length(var.public_subnet_cidrs))  : data.aws_availability_zones.this.names[i % length(data.aws_availability_zones.this.names)]]
  private_azs = [for i in range(length(var.private_subnet_cidrs)) : data.aws_availability_zones.this.names[i % length(data.aws_availability_zones.this.names)]]

  k8s_public_tags = var.add_k8s_tags ? {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  } : {}

  k8s_private_tags = var.add_k8s_tags ? {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  } : {}
}

##########
# VPC
##########
resource "aws_vpc" "this" {
  cidr_block                           = var.vpc_cidr
  instance_tenancy                     = "default"
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  assign_generated_ipv6_cidr_block     = var.enable_ipv6

  tags = merge(
    { Name = "${var.project_name}-vpc" },
    var.tags
  )
}

##########
# Internet Gateway
##########
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    { Name = "${var.project_name}-igw" },
    var.tags
  )
}

##########
# Public Subnets (+ route table & associations)
##########
# Create public subnets
resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : tostring(idx) => cidr }

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = each.value
  availability_zone               = local.public_azs[tonumber(each.key)]
  map_public_ip_on_launch         = true
  enable_resource_name_dns_a_record_on_launch = false

  tags = merge(
    { Name = "${var.project_name}-pub-${tonumber(each.key)+1}" },
    local.k8s_public_tags,
    var.tags
  )
}

# One public route table that points to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    { Name = "${var.project_name}-public-rt" },
    var.tags
  )
}

# Associate every public subnet to the public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

##########
# Private Subnets
##########
resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : tostring(idx) => cidr }

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = each.value
  availability_zone               = local.private_azs[tonumber(each.key)]
  map_public_ip_on_launch         = false
  enable_resource_name_dns_a_record_on_launch = false

  tags = merge(
    { Name = "${var.project_name}-pri-${tonumber(each.key)+1}" },
    local.k8s_private_tags,
    var.tags
  )
}
