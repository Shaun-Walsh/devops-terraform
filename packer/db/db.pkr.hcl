# This Packer template creates an Amazon Machine Image (AMI) for a MongoDB database
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "amazon_linux" {
  ami_name      = "master_db_image-${local.timestamp}"
  instance_type = "t2.nano"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username    = "ec2-user"
  ami_description = "db image for assignment 2"
  tags = {
  Name = "Assignment2" }
}
# This block is used to generate a timestamp for the AMI name
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

build {
  sources = ["source.amazon-ebs.amazon_linux"]
# This provisioner installs Docker and MongoDB on the instance
  # and starts the MongoDB container.
  # It also ensures that the MongoDB container restarts unless stopped.
  # The MongoDB container is exposed on port 27017.
provisioner "shell" {
  inline = [
    "sudo yum update -y",
    "sudo yum install -y docker",
    "sudo systemctl start docker",
    "sudo systemctl enable docker",
    "sudo docker pull mongo:latest",
    "sudo docker run -d --name mongodb --restart unless-stopped -p 27017:27017 mongo:latest"
  ]
}
}
