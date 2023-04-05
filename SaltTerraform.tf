terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.55.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDU2YZ6ZPA9TLz+I1h36bHssAQYBqeqUpUE7iy+WXGxp6cYpk7SKRu822PbpFwmiGlFGz2iQ2QqRxA5Halu5CrIFFYSRkTqtMRTKQp1KAxey5LWUF+/YWDjMlMS0ZDbsE4mSbTcNHIZ1qI2257vywk2uI/gLPF30IM7bGA816zzHCjtM32jPaGeDnv8REKi+6LdU8Ps95af+o7sgUZn2DEe+sovMyubhpXQT/z5JGBvPDZUd+WLjcbdIYOPlc2Zfg7nnn4YIbuleGSYjlWN/xx6nfQtU9XeGHtqYjAMb8l0a7+OQ+sDntI8yDyxOsL8FU6CAp+7d1BDBL9iJYGkyYAV d00417722@ssh"
}

resource "aws_instance" "minion1" {
  ami                         = "ami-00c39f71452c08778"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.instance.id]
  associate_public_ip_address = true
  key_name                    = "mykey-key"
  availability_zone = "us-east-1a"
  user_data                   = base64encode(templatefile("${path.module}/init.sh", local.vars))

  subnet_id = aws_subnet.main.id
  tags = {
    Name        = "minion1"
    Environment = "testing"
  }
}

locals {
  vars = {
    maddress = aws_instance.master.private_ip
  }
}

resource "aws_instance" "minion2" {
  ami                         = "ami-00c39f71452c08778"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.instance.id]
  associate_public_ip_address = true
  key_name                    = "mykey-key"
  availability_zone = "us-east-1a"
  user_data                   = base64encode(templatefile("${path.module}/init.sh", local.vars))


  subnet_id = aws_subnet.main.id
  tags = {
    Name        = "minion2"
    Environment = "testing"
  }
}

resource "aws_instance" "master" {
  ami                         = "ami-00c39f71452c08778"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.instance.id]
  associate_public_ip_address = true
  key_name                    = "mykey-key"
  user_data                   = <<-EOF
              #!/bin/bash
              wget -O /tmp/install.sh https://bootstrap.saltstack.com 
              chmod +x /tmp/install.sh
              source /tmp/install.sh -P -M
              EOF

  subnet_id = aws_subnet.main.id
  tags = {
    Name        = "master"
    Environment = "testing"
  }
}

resource "aws_vpc" "terraform-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.terraform-vpc.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}


resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  vpc_id = aws_vpc.terraform-vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 4505
    to_port     = 4506
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "tf"
  }
}

resource "aws_ebs_volume" "v1" {
  availability_zone = "us-east-1a"
  size              = 1
 tags = {
    Name = "forMinion1"
  }
}
resource "aws_ebs_volume" "v2" {
  availability_zone = "us-east-1a"
  size              = 1
 tags = {
    Name = "forMinion2"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.v1.id
  instance_id = aws_instance.minion1.id
}
resource "aws_volume_attachment" "ebs_att2" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.v2.id
  instance_id = aws_instance.minion2.id
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.r.id
}

output "ip_of_master" {
  value       = aws_instance.master.public_ip
  description = "Public IP of master server"
}
output "private_ip_of_master" {
  value       = aws_instance.master.private_ip
  description = "Private IP of master server"
}
output "ip_of_minion1" {
  value       = aws_instance.minion1.public_ip
  description = "Public IP of minion1 server"
}
output "ip_of_minion2" {
  value       = aws_instance.minion2.public_ip
  description = "Public IP of minion2 server"
}
