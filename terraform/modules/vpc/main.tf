resource "aws_vpc" "this" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
        Name = "${var.project_name}-${var.environment}-vpc"
    }
}

resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id

    tags = {
        Name = "${var.project_name}-${var.environment}-igw"
    }
}

resource "aws_subnet" "public" {
    count = length(var.public_subnet_cidrs)
    vpc_id = aws_vpc.this.id

    cidr_block = var.public_subnet_cidrs[count.index]

    availability_zone = var.azs[count.index]

    map_public_ip_on_launch = true

    tags = {
        Name = "${var.project_name}-${var.environment}-public-${var.azs[count.index]}"
        "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_subnet" "eks_private" {
    count = length(var.eks_private_subnet_cidrs)
    vpc_id = aws_vpc.this.id
    cidr_block = var.eks_private_subnet_cidrs[count.index]

    availability_zone = var.azs[count.index]

    tags = {
        Name = "${var.project_name}-${var.environment}-eks-private-${var.azs[count.index]}"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

resource "aws_subnet" "rds_private" {
    count = length(var.rds_private_subnet_cidrs)
    vpc_id = aws_vpc.this.id

    cidr_block = var.rds_private_subnet_cidrs[count.index]

    availability_zone = var.azs[count.index]

    tags = {
        Name = "${var.project_name}-${var.environment}-rds-private-${var.azs[count.index]}"
    }
}

resource "aws_eip" "nat" {
    count = length(var.azs)
    
    tags = {
        Name = "${var.project_name}-${var.environment}-nat-ip-${var.azs[count.index]}"
    }
}

resource "aws_nat_gateway" "this" {
    count = length(var.azs)
    allocation_id = aws_eip.nat[count.index].id

    subnet_id = aws_subnet.public[count.index].id

    tags = {
        Name = "${var.project_name}-${var.environment}-nat-${var.azs[count.index]}"
    }

    depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"

        gateway_id = aws_internet_gateway.this.id
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-public-rt"
    }
}

resource "aws_route_table_association" "public" {
        count = length(var.public_subnet_cidrs)

        subnet_id = aws_subnet.public[count.index].id

        route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
    count = length(var.azs)

    vpc_id = aws_vpc.this.id

    route {
        cidr_block = "0.0.0.0/0"

        nat_gateway_id = aws_nat_gateway.this[count.index].id
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-private-rt-${var.azs[count.index]}"
    }
}

resource "aws_route_table_association" "eks_private" {
    count = length(var.eks_private_subnet_cidrs)

    subnet_id = aws_subnet.eks_private[count.index].id

    route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "rds_private" {
    count = length(var.rds_private_subnet_cidrs)
    subnet_id = aws_subnet.rds_private[count.index].id
    route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "bastion" {
    vpc_id = aws_vpc.this.id

    name = "${var.project_name}-${var.environment}-bastion-sg"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = var.bastion_ssh_allowed_cidrs
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"

        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-${var.environment}-bastion-sg"
    }
}