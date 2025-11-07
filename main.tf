terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.4"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "ansible_key" {
  key_name   = "ansible-key"
  public_key = file("./aws_key.pub")
}

resource "aws_security_group" "orthanc_sg" {
  name        = "orthanc-sg"
  description = "Allow SSH and Orthanc traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8042
    to_port     = 8042
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4242
    to_port     = 4242
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

resource "aws_instance" "orthanc" {
  ami                    = "ami-0fc5d935ebf8bc3bc" # Ubuntu 22.04 in us-east-1
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ansible_key.key_name
  vpc_security_group_ids = [aws_security_group.orthanc_sg.id]

  tags = {
    Name = "orthanc"
  }
}

resource "aws_instance" "dicom_client" {
  ami                    = "ami-0fc5d935ebf8bc3bc"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ansible_key.key_name
  vpc_security_group_ids = [aws_security_group.orthanc_sg.id]

  tags = {
    Name = "dicom-client"
  }
}

output "inventory" {
  value = <<EOT
[orthanc]
orthanc ansible_host=${aws_instance.orthanc.public_ip}

[dicom_client]
dicom_client ansible_host=${aws_instance.dicom_client.public_ip}
EOT
}
