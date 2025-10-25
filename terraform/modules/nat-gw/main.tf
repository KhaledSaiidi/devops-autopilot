resource "aws_eip" "nat_eip" {
  for_each = toset(var.public_subnet_ids)
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  for_each      = toset(var.public_subnet_ids)
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = each.value

  tags = {
    Name = "${var.project_name}-nat-gw-${each.key}"
  }

  depends_on = [var.igw_id]
}

resource "aws_route_table" "private_rt" {
  for_each = toset(var.private_subnet_ids)

  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = values(aws_nat_gateway.nat_gw)[index(var.private_subnet_ids, each.value)].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private_assoc" {
  for_each = toset(var.private_subnet_ids)

  subnet_id      = each.value
  route_table_id = aws_route_table.private_rt[each.key].id
}
