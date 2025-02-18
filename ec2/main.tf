provider "aws" {
  region = "us-east-1"  # Change this if needed
}

# Fetch the latest RHEL 9 AMI ID dynamically
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

# EC2 Instance - Jumpbox
resource "aws_instance" "jumpbox" {
  ami                         = data.aws_ami.rhel9.id
  instance_type               = "t3.medium"
  key_name                    = "my-key"  # Replace with your key pair name
  vpc_security_group_ids      = [aws_security_group.jumpbox_sg.id]
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "Jumpbox-EC2"
  }
}

# Security Group for Jumpbox
resource "aws_security_group" "jumpbox_sg" {
  name        = "jumpbox-security-group"
  description = "Allow SSH Access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]  # 🔒 Replace with your IP (Use "0.0.0.0/0" only for testing)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# VPC
resource "aws_vpc" "voting_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.voting_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}
