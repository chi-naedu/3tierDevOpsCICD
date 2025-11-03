# Provider configuration
provider "aws" {
  region = var.aws_region
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ssm_parameter" "instance_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}