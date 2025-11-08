############################################
# Deterministic maps for for_each usage
############################################
locals {
  public_subnet_map  = { for idx, id in var.public_subnet_ids : tostring(idx) => id }
  private_subnet_map = { for idx, id in var.private_subnet_ids : tostring(idx) => id }
}

############################################
# Subnet metadata (AZ-aware mapping)
############################################
data "aws_subnet" "public" {
  for_each = local.public_subnet_map
  id       = each.value
}

data "aws_subnet" "private" {
  for_each = local.private_subnet_map
  id       = each.value
}

locals {
  nat_gateway_subnets = {
    for key, subnet in data.aws_subnet.public :
    key => {
      subnet_id = subnet.id
      az        = subnet.availability_zone
    }
  }

  private_subnets = {
    for key, subnet in data.aws_subnet.private :
    key => {
      subnet_id = subnet.id
      az        = subnet.availability_zone
    }
  }

  nat_index_by_az = {
    for key, meta in local.nat_gateway_subnets :
    meta.az => key
  }

  nat_default_index = length(local.nat_gateway_subnets) > 0 ? keys(local.nat_gateway_subnets)[0] : null

  private_nat_binding = {
    for key, meta in local.private_subnets :
    key => lookup(local.nat_index_by_az, meta.az, local.nat_default_index)
  }
}

############################################
# EIPs (one per public subnet / AZ)
############################################
resource "aws_eip" "nat_eip" {
  for_each = local.public_subnet_map
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${each.key}"
  }
}

############################################
# NAT Gateways (one per public subnet / AZ)
############################################
resource "aws_nat_gateway" "nat_gw" {
  for_each      = local.public_subnet_map
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = local.nat_gateway_subnets[each.key].subnet_id

  tags = {
    Name = "${var.project_name}-nat-gw-${each.key}"
  }

  lifecycle {
    precondition {
      condition     = local.nat_gateway_subnets[each.key].subnet_id != ""
      error_message = "Each NAT gateway requires a valid public subnet."
    }
  }
}

############################################
# Private route tables (one per private subnet / AZ)
############################################
resource "aws_route_table" "private_rt" {
  for_each = local.private_subnet_map
  vpc_id   = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[local.private_nat_binding[each.key]].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }

  lifecycle {
    precondition {
      condition     = local.nat_default_index != null
      error_message = "At least one public subnet / NAT gateway is required before creating private routes."
    }
  }
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = local.private_subnet_map
  subnet_id      = local.private_subnets[each.key].subnet_id
  route_table_id = aws_route_table.private_rt[each.key].id
}
