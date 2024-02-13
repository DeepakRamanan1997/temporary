terraform {
  required_version = "~> 1.7.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.50.0"
    }
  }
}
provider "aws" {
  region = "ap-south-1"  # Replace with your desired AWS region
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

variable "vpc_id" {
}

data "aws_vpc" "my_vpc" {
  id = var.vpc_id
}

data "aws_internet_gateway" "my_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

variable "my_security_group" {}

data "aws_security_group" "My_SG_group" {
  id = var.my_security_group
}

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = data.aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1a" # Change to your desired AZ

  tags = {
    Name = "Public Subnet"
  }
}

# Create Private Subnet 1
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = data.aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-south-1b" # Change to your desired AZ

  tags = {
    Name = "Private Subnet 1"
  }
}

# Create Private Subnet 2
resource "aws_subnet" "private_subnet_2" {
  vpc_id     = data.aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ap-south-1c" # Change to your desired AZ

  tags = {
    Name = "Private Subnet 2"
  }
}

# Create Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = data.aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "Public Subnet Route Table"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create Route Table for Private Subnet 1
resource "aws_route_table" "private_route_table_1" {
  vpc_id = data.aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "Private Subnet 1 Route Table"
  }
}

# Associate Private Subnet 1 with Private Route Table 1
resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table_1.id
}

# Create Route Table for Private Subnet 2
resource "aws_route_table" "private_route_table_2" {
  vpc_id = data.aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "Private Subnet 2 Route Table"
  }
}

# Associate Private Subnet 2 with Private Route Table 2
resource "aws_route_table_association" "private_subnet_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table_2.id
}

# Create NAT Gateway for Private Subnets
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = data.aws_eip.my_nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "NATGateway"
  }
}

data "aws_eip" "my_nat_eip" {
  tags = {
    Name = "VijayWindowDND"
  }
}

# Declare AWS IAM Role
resource "aws_iam_role" "example" {
  name = "Example-EKS-role"

  assume_role_policy = jsonencode(
  {
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
   }
  )
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.example.name
}

resource "aws_eks_cluster" "example" {
  name     = "Example"
  role_arn = aws_iam_role.example.arn

  vpc_config {
    subnet_ids = [aws_subnet.private_subnet_1.id,aws_subnet.private_subnet_2.id]
    security_group_id = [data.aws_security_group.My_SG_group.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.example.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.example.certificate_authority[0].data
}

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "example"
  node_role_arn   = aws_iam_role.example.arn
  subnet_ids      = [aws_subnet.private_subnet_1.id,aws_subnet.private_subnet_2.id]
  instance_types = ["t2.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id_1" {
  value = aws_subnet.private_subnet_1.id
}

output "private_subnet_id_2" {
  value = aws_subnet.private_subnet_2.id
}

