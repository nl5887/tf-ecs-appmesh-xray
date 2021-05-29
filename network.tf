resource "aws_vpc" "app-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_classiclink = "false"
  instance_tenancy = "default"    
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = merge(local.tags, {
    Name = "app-vpc"
    // Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
  })
}

resource "aws_vpc_dhcp_options" "foo" {
  domain_name          = "${local.name}.local"
  domain_name_servers  = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.app-vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.foo.id
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.app-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names.0

  tags = merge(local.tags, {
    Name = "subnet-${aws_vpc.app-vpc.tags.Name}-public-${data.aws_availability_zones.available.names.1}"
    // Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
  })
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.app-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names.1

  tags = merge(local.tags, {
    Name = "subnet-${aws_vpc.app-vpc.tags.Name}-private-${data.aws_availability_zones.available.names.1}"
    // Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
  })

  /*
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.example.id}"
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${element(data.aws_availability_zones.available.names, count.index)}"
  tags = {
    Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
  }
  */
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app-vpc.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app-vpc.id
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app-vpc.id
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.nat.id

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_ngw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}

output "vpc" {
  value = aws_vpc.app-vpc
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}
