provider "aws" {
  region = "us-east-1"
}

# Fetch the latest RHEL 9 AMI from AWS Official Red Hat Account
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"]  # AWS Official Red Hat Account

  filter {
    name   = "name"
    values = ["RHEL-9*"]  # Fetch the latest RHEL 9 AMI
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Generate an SSH Key Pair (Terraform manages this)
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save the key pair locally (so you can use it to SSH)
resource "local_file" "private_key" {
  content         = tls_private_key.key_pair.private_key_pem
  filename        = "${path.module}/jumpbox-key.pem"
  file_permission = "0400"
}

# Create the key pair in AWS
resource "aws_key_pair" "generated_key" {
  key_name   = "jumpbox-key"
  public_key = tls_private_key.key_pair.public_key_openssh
}

# Get your public IP dynamically (for SSH security)
data "http" "my_ip" {
  url = "http://checkip.amazonaws.com"
}

# Create a VPC
resource "aws_vpc" "voting_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway (Needed for Public Access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.voting_vpc.id
}

# Create a Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.voting_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Public Subnet (Auto-assigns Public IP)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.voting_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Associate the Public Subnet with the Public Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for Jumpbox (Allows SSH from your IP only)
resource "aws_security_group" "jumpbox_sg" {
  name        = "jumpbox-security-group"
  description = "Allow SSH Access"
  vpc_id      = aws_vpc.voting_vpc.id 

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]  # Auto-detects your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance - Jumpbox
resource "aws_instance" "jumpbox" {
  ami                         = data.aws_ami.rhel9.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.jumpbox_sg.id]
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "Jumpbox-EC2"
  }
}

# Output the instance Public IP
output "instance_public_ip" {
  value = aws_instance.jumpbox.public_ip
}

# Output SSH command to connect
output "ssh_command" {
  value = "ssh -i jumpbox-key.pem ec2-user@${aws_instance.jumpbox.public_ip}"
}
