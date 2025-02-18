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
  content  = tls_private_key.key_pair.private_key_pem
  filename = "${path.module}/jumpbox-key.pem"
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

# Security Group for Jumpbox (Allows SSH from your IP only)
resource "aws_security_group" "jumpbox_sg" {
  name        = "jumpbox-security-group"
  description = "Allow SSH Access"

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
 /* 
  The above Terraform code creates an EC2 instance (Jumpbox) in a public subnet with a security group that allows SSH access from your IP only. 
  The Jumpbox is based on the latest RHEL 9 AMI and uses an SSH key pair that Terraform generates. The public IP of the Jumpbox is outputted at the end, along with the SSH command to connect to it. 
  Step 3: Deploy the Jumpbox 
  Now, let’s deploy the Jumpbox using Terraform. 
*/