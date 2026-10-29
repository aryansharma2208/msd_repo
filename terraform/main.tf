terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = var.name
      ManagedBy = "terraform"
    }
  }
}

# Latest Amazon Linux 2023 AMI (free-tier eligible), looked up at plan time.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Use the account's default VPC to keep the setup small.
data "aws_vpc" "default" {
  default = true
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.name}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_security_group" "web" {
  name        = "${var.name}-sg"
  description = "HTTP from anywhere, SSH only from the admin IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "Outbound for OS package updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.admin.key_name
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  # cloud-init installs the app and systemd units on first boot.
  # Files are passed base64-encoded so their content is copied exactly.
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    app_py            = filebase64("${path.module}/../app/app.py")
    service_unit      = filebase64("${path.module}/../deploy/hello.service")
    healthcheck_sh    = filebase64("${path.module}/../deploy/healthcheck.sh")
    healthcheck_unit  = filebase64("${path.module}/../deploy/hello-healthcheck.service")
    healthcheck_timer = filebase64("${path.module}/../deploy/hello-healthcheck.timer")
  })
  # Changing the app or units replaces the instance (simple, repeatable deploys).
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = var.name
  }
}
