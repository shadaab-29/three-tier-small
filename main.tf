terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ------------------------
# VPC
# ------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# ------------------------
# Subnets
# ------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "${var.project}-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "${var.project}-private-subnet"
  }
}

# ------------------------
# Route Table
# ------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

# ------------------------
# Security Groups
# ------------------------
resource "aws_security_group" "bastion_sg" {
  name   = "${var.project}-bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-bastion-sg"
  }
}

resource "aws_security_group" "private_sg" {
  name   = "${var.project}-private-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [
      aws_security_group.bastion_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-private-sg"
  }
}

# ------------------------
# Key Pair
# ------------------------
resource "aws_key_pair" "main" {
  key_name   = "${var.project}-key"
  public_key = file(var.public_key_path)
}

# ------------------------
# Bastion Host (Public EC2)
# ------------------------
resource "aws_instance" "bastion" {
  ami           = var.ami
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.main.key_name
  security_groups = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "${var.project}-bastion"
  }
}

# ------------------------
# Private App Server (Private EC2)
# ------------------------
resource "aws_instance" "app" {
  ami           = var.ami
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private.id
  key_name      = aws_key_pair.main.key_name
  security_groups = [aws_security_group.private_sg.id]

  tags = {
    Name = "${var.project}-app"
  }
}
