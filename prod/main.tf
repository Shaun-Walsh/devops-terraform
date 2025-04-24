
# data source to get latest amazon linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_instance_profile" "lab_instance_profile" {
  name = "LabInstanceProfile"
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name = "Bastion"
  }
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = module.vpc.private_subnets[0]
  associate_public_ip_address = false
  iam_instance_profile        = data.aws_iam_instance_profile.lab_instance_profile.name
}
