############################################
# Index sets
############################################
locals {
  public_indexes  = { for idx in range(length(var.public_subnet_cidrs)) : idx => idx }
  private_indexes = { for idx in range(length(var.private_subnet_cidrs)) : idx => idx }
}

############################################
# EIPs (one per public subnet / AZ)
############################################
resource "aws_eip" "nat_eip" {
  for_each = local.public_indexes
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${each.key}"
  }
}

############################################
# NAT Gateways (one per public subnet / AZ)
############################################
resource "aws_nat_gateway" "nat_gw" {
  for_each      = local.public_indexes
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = var.public_subnet_ids[each.key]

  tags = {
    Name = "${var.project_name}-nat-gw-${each.key}"
  }
}

############################################
# Private route tables (one per private subnet / AZ)
############################################
resource "aws_route_table" "private_rt" {
  for_each = local.private_indexes
  vpc_id   = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[each.key].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = local.private_indexes
  subnet_id      = var.private_subnet_ids[each.key]
  route_table_id = aws_route_table.private_rt[each.key].id
}
