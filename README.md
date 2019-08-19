# AWS-Blue-Green-Deployment-Terraform
Terraform Blue Green deployment with lambda 

Steps:
cd into Terraform2 folder to setup the infrastructure bring up all resources require for the blue green
1. Run terraform init
2. Run terraform apply

then, cd into Terraform3 folder. this is to where we have the LAMBDA function triggered by SNS 
1. Run terraform init
2. Run terraform apply
3. Run aws sns publish --topic-arn arn:aws:sns:(enter your region):(enter you aws id):call-lambda-maybe --message "This is me"

This works perfectly immutable switching from blue to green.

![](data1.png)
