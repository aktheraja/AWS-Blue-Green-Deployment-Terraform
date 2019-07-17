
resource "aws_lambda_permission" "with_sns" {
  depends_on = ["aws_sns_topic_subscription.lambda"]
  statement_id = "AllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.func.function_name}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.default.arn}"
}

resource "aws_sns_topic" "default" {
  name = "call-lambda-maybe"

}



resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = "${aws_sns_topic.default.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.func.arn}"

}

resource "aws_lambda_function" "func" {
  filename      = "Terraform_lambda.zip"
  function_name = "lambda_called_from_sns"
  role          = "${aws_iam_role.default.arn}"
  handler       = "Terraform_lambda.lambda_handler"
  runtime       = "python2.7"
  timeout = "900"
  memory_size = "512"
  source_code_hash = "${filebase64sha256("Terraform_lambda.zip")}"
  environment {
    variables = {
      asg_blue  = "asg_blue"
      asg_green = "asg_green"
      ami    = "ami-07669fc90e6e6cc47"

    }
  }

}

resource "aws_iam_role" "default" {
  name = "iam_for_lambda_with_sns"

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_policy" "lifecycle" {
  name = "tf_lambda_vpc_policy"
  path   = "/"
  policy = <<EOF
{

    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]

}

EOF
}

resource "aws_iam_policy_attachment" "lifecycle" {
  name      = "tf-iam-role-attachment-lifecycle"
  roles      = ["${aws_iam_role.default.name}"]
  policy_arn = "${aws_iam_policy.lifecycle.arn}"

}