data "aws_ami" "latest_swalsh_assignment2_appserver" {
  most_recent = true

  owners = ["self"]

  filter {
    name   = "name"
    values = ["swalsh_assignment2_appserver*"]
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  # Application Load Balancer
  name                  = "swalsh-alb"
  internal              = false
  load_balancer_type    = "application"
  create_security_group = false
  security_groups       = [aws_security_group.alb.id]
  vpc_id                = module.vpc.vpc_id
  subnets               = module.vpc.public_subnets

  listeners = {
    ex-http-https-redirect = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    ex-https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = "arn:aws:acm:us-east-1:289428676388:certificate/35ee24d5-b86a-4637-9448-0c5ea0086103" # Create cert in terraform

      forward = {
        target_group_key = "app"
      }
    }
  }

  target_groups = {
    app = {
      backend_protocol                  = "HTTP"
      name                              = "app"
      port                              = 3000
      target_type                       = "instance"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

       # Enable stickiness
      stickiness = {
        enabled = true
        type    = "lb_cookie"
        cookie_duration = 86400 # 1 day
      }

      # There's nothing to attach here in this definition.
      # The attachment happens in the ASG module below
      create_attachment = false
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        timeout             = 5
        unhealthy_threshold = 2
        path                = "/testlb"
      }
    }
  }

  enable_deletion_protection = false

  tags = {
    Name = "swalsh-assignment2-alb"
  }
}

module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = "swalsh-app"

  min_size                  = 1
  max_size                  = 5
  desired_capacity          = 2
  health_check_type         = "ELB" # Ensure it considers the app health check
  health_check_grace_period = 30
  vpc_zone_identifier       = module.vpc.private_subnets
  security_groups           = [aws_security_group.app.id]

  traffic_source_attachments = {
    ex-alb = {
      traffic_source_identifier = module.alb.target_groups["app"].arn
      traffic_source_type       = "elbv2" # default
    }
  }

  # Launch template
  create_launch_template = true
  update_default_version = true

  image_id          = data.aws_ami.latest_swalsh_assignment2_appserver.id
  instance_type     = "t2.nano"
  ebs_optimized     = true
  enable_monitoring = true


  # IAM role & instance profile
  create_iam_instance_profile = false
  iam_instance_profile_name   = data.aws_iam_instance_profile.lab_instance_profile.name


  tags = {
    Name = "swalsh-assignemnt2-asg"
  }
}

resource "aws_autoscaling_policy" "increase" {
  name                   = "increase"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = module.asg.autoscaling_group_name
  policy_type            = "SimpleScaling"

}

resource "aws_autoscaling_policy" "decrease" {
  name                   = "decrease"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = module.asg.autoscaling_group_name
  policy_type            = "SimpleScaling"

}

resource "aws_cloudwatch_metric_alarm" "scale_out" {
  alarm_name          = "scale_out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out if CPU > 70% for 60 seconds"
  alarm_actions       = [aws_autoscaling_policy.increase.arn]
  dimensions = {
    AutoScalingGroupName = module.asg.autoscaling_group_name
  }
  actions_enabled = true

}

resource "aws_cloudwatch_metric_alarm" "scale_in" {
  alarm_name          = "scale_in"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in if CPU < 30% for 1 seconds"
  alarm_actions       = [aws_autoscaling_policy.decrease.arn]
  dimensions = {
    AutoScalingGroupName = module.asg.autoscaling_group_name
  }
  actions_enabled = true

}

