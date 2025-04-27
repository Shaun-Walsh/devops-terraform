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
  key_name = "shaunskey"

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

# Store the DB endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/assignment2/db_endpoint"
  description = "Database connection string"
  type        = "String"
  value       = aws_instance.db.private_ip
  overwrite   = true
}
