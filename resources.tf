resource "aws_vpc" "vpc_environment" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public_subnet1" {
  cidr_block              = cidrsubnet(aws_vpc.vpc_environment.cidr_block, 4, 1)
  vpc_id                  = aws_vpc.vpc_environment.id
  availability_zone       = "us-west-2c"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet1" {
  cidr_block        = cidrsubnet(aws_vpc.vpc_environment.cidr_block, 4, 2)
  vpc_id            = aws_vpc.vpc_environment.id
  availability_zone = "us-west-2c"
}

resource "aws_subnet" "public_subnet2" {
  cidr_block              = cidrsubnet(aws_vpc.vpc_environment.cidr_block, 4, 3)
  vpc_id                  = aws_vpc.vpc_environment.id
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet2" {
  cidr_block        = cidrsubnet(aws_vpc.vpc_environment.cidr_block, 4, 4)
  vpc_id            = aws_vpc.vpc_environment.id
  availability_zone = "us-west-2b"
}

resource "aws_security_group" "private_subnesecurity" {
  vpc_id = aws_vpc.vpc_environment.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = -1
    protocol    = "icmp"
    to_port     = -1
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "security" {
  vpc_id = aws_vpc.vpc_environment.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = -1
    protocol    = "icmp"
    to_port     = -1
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "ami_key_pair_name" {
  default = "MyKP"
}

//internet gateway
resource "aws_internet_gateway" "default_gat" {
  vpc_id = aws_vpc.vpc_environment.id
}

//routing table for public subnets
resource "aws_route_table" "route-public" {
  vpc_id = aws_vpc.vpc_environment.id
  //depends_on = [aws_vpc.vpc_environment]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default_gat.id
  }

  tags = {
    Name = "vpc Routing Table"
  }
}

//routing table for private subnet 1
resource "aws_route_table" "route-private1" {
  vpc_id = aws_vpc.vpc_environment.id
  //  depends_on = [aws_subnet.private_subnet1]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_1gate.id
  }

  tags = {
    Name = "Private Subnet 1 Routing Table"
  }
}

//routing table for private subnet 2
resource "aws_route_table" "route-private2" {
  vpc_id = aws_vpc.vpc_environment.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_1gate.id
  }

  tags = {
    Name = "Private Subnet 2 Routing Table"
  }
}

resource "aws_main_route_table_association" "main_table_assoc" {
  vpc_id         = aws_vpc.vpc_environment.id
  route_table_id = aws_route_table.route-public.id
}

resource "aws_route_table_association" "subnet1_table_assoc" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.route-private1.id
}
resource "aws_route_table_association" "subnet2_table_assoc" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.route-private2.id
}

resource "aws_launch_configuration" "autoscale_launch_config" {
  name          = "autoscale_launcher-Akin"
  image_id        = "ami-07669fc90e6e6cc47"
  instance_type   = "t2.nano"
  //  key_name        = var.ami_key_pair_name
  security_groups = [aws_security_group.security.id]
  enable_monitoring = true
  user_data = file(
  "C:/Users/akfre/OneDrive/Documents/install_apache_server.sh"
  )
}
resource "aws_nat_gateway" "nat_2gate" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.public_subnet2.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "nat_1gate" {

  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "nat_eip2" {

  vpc      = true
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_eip" "nat_eip" {

  vpc      = true
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscale_group_1" {
  //  depends_on = [aws_lambda_function.test_lambda]
  name="asg_blue"
  launch_configuration = aws_launch_configuration.autoscale_launch_config.id
  vpc_zone_identifier  = [aws_subnet.private_subnet2.id, aws_subnet.private_subnet1.id]

  initial_lifecycle_hook {
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    heartbeat_timeout = 100
    //	default_result = "CONTINUE"
    name = "delay"
  }
  min_size = 2
  max_size = 5
  desired_capacity = 3

  tag {
    key                 = "Name"
    value               = "auto_scale-akin_blue"
    propagate_at_launch = true
  }
  health_check_grace_period = 200
  health_check_type = "ELB"
  //load_balancers = [aws_alb.alb.name]
  lifecycle {create_before_destroy = true}
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity="1Minute"

}

resource "aws_autoscaling_group" "autoscale_group_2" {
  //  depends_on = [aws_lambda_function.test_lambda]
  name="asg_green"
  launch_configuration = aws_launch_configuration.autoscale_launch_config.id
  vpc_zone_identifier  = [aws_subnet.private_subnet2.id, aws_subnet.private_subnet1.id]

  initial_lifecycle_hook {
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    heartbeat_timeout = 100
    //	default_result = "CONTINUE"
    name = "delay"
  }
  min_size = 0
  max_size = 0
  desired_capacity = 0

  tag {
    key                 = "Name"
    value               = "auto_scale_1_akin_green"
    propagate_at_launch = true
  }
  health_check_grace_period = 200
  health_check_type = "ELB"
  //load_balancers = [aws_alb.alb.name]
  lifecycle {create_before_destroy = true}
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity="1Minute"

}

resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  //cooldown = 300

  autoscaling_group_name = "${aws_autoscaling_group.autoscale_group_1.id}"
  //  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}

resource "aws_autoscaling_policy" "web_policy_up1" {
  name = "web_policy_up1"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  //cooldown = 300

  autoscaling_group_name = "${aws_autoscaling_group.autoscale_group_2.id}"
  //  autoscaling_group_name = "${aws_autoscaling_group.web.name}"
}

resource "aws_autoscaling_attachment" "alb_autoscale" {
  alb_target_group_arn   = aws_alb_target_group.alb_target_group_1.id
  autoscaling_group_name = aws_autoscaling_group.autoscale_group_1.id
}
resource "aws_autoscaling_attachment" "alb_autoscale2" {
  alb_target_group_arn   = aws_alb_target_group.alb_target_group_1.id
  autoscaling_group_name = aws_autoscaling_group.autoscale_group_2.id
}
resource "aws_alb_target_group" "alb_target_group_1" {
  name     = "alb-target-group-2"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_environment.id

  tags = {
    name = "alb_target_group2"
  }
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }
  //slow_start = 120
  //  deregistration_delay = 120
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 2
    interval            = 5
    path                = "/"
    port                = 80
  }

}

resource "aws_alb" "alb" {
  name = "alb-Akin"
  subnets = [
    aws_subnet.public_subnet1.id,
    aws_subnet.public_subnet2.id]
  security_groups = [
    aws_security_group.security.id]
  internal = false
  idle_timeout = 60
  tags = {
    Name = "alb2"
  }
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group_1.arn
    type             = "forward"
  }
}

//
//resource "aws_lambda_permission" "with_sns" {
//  statement_id  = "AllowExecutionFromSNS"
//  action        = "lambda:InvokeFunction"
//  function_name = "${aws_lambda_function.func.function_name}"
//  principal     = "sns.amazonaws.com"
//  source_arn    = "${aws_sns_topic.default.arn}"
//}
//
//resource "aws_sns_topic" "default" {
//  name = "call-lambda-maybe"
//}
//
//resource "aws_sns_topic_subscription" "lambda" {
// // depends_on = ["aws_lambda_function.func"]
//  topic_arn = "${aws_sns_topic.default.arn}"
//  protocol  = "lambda"
//  endpoint  = "${aws_lambda_function.func.arn}"
//}
//
//resource "aws_lambda_function" "func" {
//  filename      = "Terraform.zip"
//  function_name = "lambda_called_from_sns"
//  role          = "${aws_iam_role.default.arn}"
//  handler       = "Terraform.handler"
//  runtime       = "nodejs8.10"
//
//}
//
//resource "aws_iam_role" "default" {
//  name = "iam_for_lambda_with_sns"
//
//  assume_role_policy = <<EOF
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Action": "sts:AssumeRole",
//      "Principal": {
//        "Service": "lambda.amazonaws.com"
//      },
//      "Effect": "Allow",
//      "Sid": ""
//    }
//  ]
//}
//EOF
//}
//
//
//resource "aws_iam_policy" "lifecycle" {
//  name   = "tf_lambda_vpc_policy"
//  path   = "/"
//  policy = <<EOF
//{
//
//	"Version": "2012-10-17",
//	"Statement": [
//	{
//			"Effect": "Allow",
//			"Action": [
//				"logs:CreateLogGroup",
//				"logs:CreateLogStream",
//				"logs:PutLogEvents"
//			],
//			"Resource": "arn:aws:logs:*:*:*"
//		},
//		{
//			"Effect": "Allow",
//			"Resource": "arn:aws:dynamodb:us-west-2:632199730033:table/Message",
//			"Action": "dynamodb:*"
//		}
//	]
//}
//
//EOF
//}
//
//resource "aws_iam_policy_attachment" "lifecycle" {
//  name       = "tf-iam-role-attachment-lifecycle"
//  roles      = ["${aws_iam_role.default.name}"]
//  policy_arn = "${aws_iam_policy.lifecycle.arn}"
//}