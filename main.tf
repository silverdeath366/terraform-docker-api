provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Allow HTTP inbound"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Allow all from ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "docker_api" {
  name_prefix   = "docker-api-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    docker run -d -p 80:80 ${var.docker_image}:${var.docker_tag}
  EOF
  )
}

resource "aws_lb" "api_lb" {
  name               = "docker-api-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "api_tg" {
  name     = "docker-api-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

resource "aws_autoscaling_group" "api_asg" {
  desired_capacity     = var.desired_capacity
  max_size             = 4
  min_size             = 1
  vpc_zone_identifier  = var.public_subnets
  launch_template {
    id      = aws_launch_template.docker_api.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.api_tg.arn]

  tag {
    key                 = "Name"
    value               = "docker-api-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.api_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-util-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.api_asg.name
  }
}
