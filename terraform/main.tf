provider "aws" {
  region = "us-east-1"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group to allow SSH and HTTP
resource "aws_security_group" "ubuntu_sg" {
  name        = "ubuntu-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ubuntu-sg"
  }
}

# Generate SSH key pair
resource "tls_private_key" "ubuntu_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Upload public key to AWS
resource "aws_key_pair" "ubuntu_key" {
  key_name   = "ubuntu-shared-key"
  public_key = tls_private_key.ubuntu_key.public_key_openssh
}

# Save private key locally as PEM file
resource "local_file" "private_key_pem" {
  filename = "${path.module}/ubuntu-shared-key.pem"
  content  = tls_private_key.ubuntu_key.private_key_pem
  file_permission = "0600"
}

# Latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch 3 Ubuntu instances
resource "aws_instance" "ubuntu" {
  count                       = 3
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ubuntu_key.key_name
  vpc_security_group_ids      = [aws_security_group.ubuntu_sg.id]

  tags = {
    Name = "Ubuntu-Server-${count.index}"
  }
}

