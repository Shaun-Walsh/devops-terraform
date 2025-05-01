# This file creates the vpc and subnets for the application.
# It uses the terraform-aws-modules/vpc/aws module to create the VPC and subnets.
# It also creates the security groups for the application load balancer, application, database, and bastion host.
provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  name   = "swalsh-vpc"
  region = "us-east-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Example    = local.name
    GithubRepo = "devops-terraform"
    GithubOrg  = "Shaun-Walsh"
  }
}
#Create the VPC and subnets
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 8)]

  create_database_subnet_group = false
  enable_nat_gateway           = true
  single_nat_gateway           = true
  tags                         = local.tags
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Allow HTTP and HTTPS traffic to the ALB"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "${local.name}-alb"
  }

}

# Create security group rules for the ALB
resource "aws_security_group_rule" "alb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}
# Create security group for the application
resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "App sgroup"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "${local.name}-app"
  }
}

resource "aws_security_group_rule" "app_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.app.id
  cidr_blocks       = ["0.0.0.0/0"]

}

resource "aws_security_group_rule" "app_ingress" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "app_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.app.id
  cidr_blocks       = ["0.0.0.0/0"]
}
# Create security group for the database
resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "DB mongo sg"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "${local.name}-db"
  }
}

resource "aws_security_group_rule" "db_ingress" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "db_bastion_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.bastion.id

}
# Create security group for the bastion host
resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion"
  description = "Bastion host security group"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "${local.name}-bastion"
  }
}

resource "aws_security_group_rule" "bastion_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.bastion.id
  cidr_blocks       = ["0.0.0.0/0"]
}
