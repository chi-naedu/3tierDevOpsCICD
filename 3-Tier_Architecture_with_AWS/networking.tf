# Networking Layer: VPC, Subnets, IGW, NAT Gateway

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = { Name = "main-igw" }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-2" }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2a"
  tags = { Name = "private-subnet-1" }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-2b"
  tags = { Name = "private-subnet-2" }
}

resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet_2.id
  tags = { Name = "main-nat" }
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.main_igw]
}
