provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

# Fetch the latest RHEL 8 AMI ID
data "aws_ssm_parameter" "rhel8_ami" {
  name = "/aws/service/redhat/rhel8/latest/image_id"
}

resource "aws_instance" "jumpbox" {
  ami             = data.aws_ssm_parameter.rhel8_ami.value
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
