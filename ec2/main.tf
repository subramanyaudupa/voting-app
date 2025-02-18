provider "aws" {
  region = "us-east-1" # Change if needed
}

resource "aws_instance" "jumpbox" {
  ami             = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 (Update AMI ID if needed)
  instance_type   = "t3.medium"
  key_name        = "my-key"  # Replace with your key-pair name
  vpc_security_group_ids = [aws_security_group.jumpbox_sg.id]
  subnet_id       = aws_subnet.public_subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "Jumpbox-EC2"
  }
}

resource "aws_security_group" "jumpbox_sg" {
  name        = "jumpbox-security-group"
  description = "Allow SSH Access"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production!
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc" "voting_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.voting_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}
