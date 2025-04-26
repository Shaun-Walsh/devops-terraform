data "aws_ami" "master_db_image" {
  most_recent = true

  owners = ["self"]

  filter {
    name   = "name"
    values = ["master_db_image*"]
  }
}

resource "aws_instance" "db" {
  ami           = data.aws_ami.master_db_image.id
  instance_type = "t2.nano"

  tags = {
    Name = "DB"
  }
  vpc_security_group_ids      = [aws_security_group.db.id]
  subnet_id                   = module.vpc.private_subnets[1]
  associate_public_ip_address = false
  iam_instance_profile        = data.aws_iam_instance_profile.lab_instance_profile.name
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}
