packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "amazon_linux" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = "t2.small"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.7*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username    = "ec2-user"
  ami_description = "Master image for assignment 2"
  tags = {
    Name = "Assignment2-Master" }
}

variable "ami_prefix" {
  type    = string
  default = "swalsh_assignment2_appserver"
}

variable "cookie_name" {
  type        = string
  description = "Cookie name for the application"
}

variable "cookie_password" {
  type        = string
  description = "Cookie password for the application"
  sensitive   = true
}

variable "db" {
  type        = string
  description = "Database connection string"
  sensitive   = true
}

variable "cloudinary_name" {
  type        = string
  description = "Cloudinary account name"
}

variable "cloudinary_key" {
  type        = string
  description = "Cloudinary API key"
  sensitive   = true
}

variable "cloudinary_secret" {
  type        = string
  description = "Cloudinary API secret"
  sensitive   = true
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}


build {
  name = "Assignment2"
  sources = [
    "source.amazon-ebs.amazon_linux"
  ]

  provisioner "file" {
    source      = "mem.sh"
    destination = "/tmp/mem.sh"
  }

  provisioner "file" {
    source      = "placemark.service"
    destination = "/tmp/placemark.service"
  }

  provisioner "file" {
    source      = "test.sh"
    destination = "/tmp/test.sh"
  }

  provisioner "shell" {
    inline = [
      # Update system and install necessary packages
      "sudo yum update -y",
      "sudo yum install cronie cronie-anacron -y",
      "sudo systemctl enable crond",
      "sudo systemctl start crond",

      # Move the script and set permissions
      "sudo mv /tmp/mem.sh /home/ec2-user/mem.sh",
      "sudo chmod +x /home/ec2-user/mem.sh",
      "sudo chown ec2-user:ec2-user /home/ec2-user/mem.sh",
      "sudo mv /tmp/test.sh /home/ec2-user/test.sh",
      "sudo chmod +x /home/ec2-user/test.sh",
      "sudo chown ec2-user:ec2-user /home/ec2-user/test.sh",
      "echo '*/1 * * * * /home/ec2-user/mem.sh' | sudo crontab -u ec2-user -",
      "sudo mv /tmp/placemark.service /etc/systemd/system/placemark.service",

      # Install Node.js, dependencies, and clone the GitHub repository
      "sudo yum install -y nodejs",
      "sudo yum install -y git",
      "git clone https://github.com/Shaun-Walsh/placemark.git",

      # Change into the placemark directory
      "cd placemark",

      # Write sensitive data into the .env file inside the placemark directory
      "echo cookie_name=${var.cookie_name} > .env",
      "echo cookie_password=${var.cookie_password} >> .env",
      "echo db=${var.db} >> .env",
      "echo cloudinary_name=${var.cloudinary_name} >> .env",
      "echo cloudinary_key=${var.cloudinary_key} >> .env",
      "echo cloudinary_secret=${var.cloudinary_secret} >> .env",

      # Install project dependencies
      "npm install",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable placemark.service",
      "sudo systemctl start placemark.service"
    ]
  }

}
