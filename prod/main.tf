# This file creates the bastion host instance.
data "aws_iam_instance_profile" "lab_instance_profile" {
  name = "LabInstanceProfile"
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.latest_swalsh_assignment2_appserver.id
  instance_type = "t2.nano"

  tags = {
    Name = "Bastion"
  }
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = module.vpc.private_subnets[0]
  associate_public_ip_address = false
  iam_instance_profile        = data.aws_iam_instance_profile.lab_instance_profile.name
}



