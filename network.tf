resource "aws_vpc" "current" {
  cidr_block           = "10.0.0.0/16"
  enable_classiclink   = "false"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.name}-vpc"
    // Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
  })
}

resource "aws_vpc_dhcp_options" "current" {
  domain_name         = "${local.name}.local"
  domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.current.id
  dhcp_options_id = aws_vpc_dhcp_options.current.id
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.current.id
  cidr_block              = "10.0.${count.index*10+0}.0/24"
  map_public_ip_on_launch = false
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = merge(local.tags, {
    Name = "${aws_vpc.current.tags.Name}-public-${element(data.aws_availability_zones.available.names, count.index)}"
  })
}


resource "aws_subnet" "private" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.current.id
  cidr_block              = "10.0.${count.index*10+1}.0/24"
  map_public_ip_on_launch = false
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = merge(local.tags, {
    Name = "${aws_vpc.current.tags.Name}-private-${element(data.aws_availability_zones.available.names, count.index)}"
  })
}

resource "aws_route_table" "public" {
  count         = length(aws_subnet.public)
  vpc_id = aws_vpc.current.id
}

resource "aws_route_table" "private" {
  count         = length(aws_subnet.private)
  vpc_id = aws_vpc.current.id
}

resource "aws_route_table_association" "public_subnet" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "private_subnet" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_eip" "nat" {
  count         = length(aws_subnet.public)
  vpc = true
}

resource "aws_internet_gateway" "current" {
  vpc_id = aws_vpc.current.id
}

resource "aws_nat_gateway" "current" {
  count         = length(aws_subnet.public)
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id

  depends_on = [aws_internet_gateway.current]
}

resource "aws_route" "public_igw" {
  count                  = length(aws_subnet.public)
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.current.id
}

resource "aws_route" "private_ngw" {
  count                  = length(aws_subnet.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.current[count.index].id
}

output "vpc" {
  value = aws_vpc.current
}
