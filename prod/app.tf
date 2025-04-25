# look up AMI id for app server
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
  name               = "swalsh"
  internal           = false
  load_balancer_type = "application"
  create_security_group = false
  security_groups = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "swalsh-assignment2-alb"
  }
}
resource "aws_alb_target_group" "tg" {
  name     = "swalsh-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol = "HTTP"
    port                = "3000"
    interval            = 30
    timeout             = 4
    healthy_threshold  = 3
    unhealthy_threshold = 3
    matcher             = "200-299"
  }

  tags = {
    Name = "swalsh-assignment2-tg"
  }
  
}
resource "aws_lb_listener" "lb_http" {
  load_balancer_arn = module.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.tg.arn
  }
  
}

module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  # Autoscaling group
  name = "swalsh"

  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  health_check_type         = "ELB"
  health_check_grace_period = 30
  vpc_zone_identifier       = module.vpc.public_subnets
  security_groups           = [aws_security_group.app.id]


  # Launch template
  create_launch_template = true
  update_default_version = true

  image_id          = data.aws_ami.latest_swalsh_assignment2_appserver.id
  instance_type     = "t2.micro"
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
  cooldown               = 300
  autoscaling_group_name = module.asg.autoscaling_group_name
  policy_type            = "SimpleScaling"

}

resource "aws_autoscaling_policy" "decrease" {
  name                   = "decrease"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = module.asg.autoscaling_group_name
  policy_type            = "SimpleScaling"

}

resource "aws_cloudwatch_metric_alarm" "scale_out" {
  alarm_name          = "scale_out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 30
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out if CPU > 70% for 5 minutes"
  alarm_actions       = [aws_autoscaling_policy.increase.arn]
  dimensions          = {
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
  period              = 30
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in if CPU < 30% for 5 minutes"
  alarm_actions       = [aws_autoscaling_policy.decrease.arn]
  dimensions          = {
    AutoScalingGroupName = module.asg.autoscaling_group_name
  }
  actions_enabled = true
  
}
