resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.environment_name}-vpc" })
}

# ── Public Subnets ────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                                   = "${var.environment_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                               = "1"
    "kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"
  })
}

# ── Private Subnets ───────────────────────────────────────────────────────────

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                                                   = "${var.environment_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${var.environment_name}-cluster" = "shared"
  })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.environment_name}-igw" })
}

# ── NAT Gateway (1 per VPC — cost-conscious; noted trade-off in APPROACH.md) ─

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.environment_name}-nat-eip" })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags       = merge(var.tags, { Name = "${var.environment_name}-nat" })
  depends_on = [aws_internet_gateway.main]
}

# ── Route Tables ──────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.tags, { Name = "${var.environment_name}-public-rt" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = merge(var.tags, { Name = "${var.environment_name}-private-rt" })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
