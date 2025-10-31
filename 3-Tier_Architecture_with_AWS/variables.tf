# ECS Instance Type for ECS Container Instances
variable "ecs_instance_type" {
  description = "EC2 instance type for ECS container instances"
  default     = "t3.medium"
}

# SSH Key Name for ECS Container Instances
variable "key_name" {
  description = "Name of the AWS key pair for ECS container instances"
  default     = "cba_keypair" # update with your key pair name
}

# Private Subnets for ECS Container Instances
# variable "private_subnets" {
#   description = "List of private subnet IDs for ECS container instances"
#   type        = list(string)
# }
# Variables for the 3-tier architecture

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  default     = "10.0.3.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  default     = "10.0.4.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for EC2 instances"
  default     = "cba_keypair" #update with your key pair name
}

# Database variables
# variable "db_username" {
#   description = "Username for the RDS database"
#   default    = "mydb"
# }

# variable "db_password" {
#   description = "Password for the RDS database"
#   default   = "mydbinstance"
# }

# variable "db_name" {
#   description = "Database name"
#   default     = "mydb"
# }

# variable "db_host" {
#   description = "Database host endpoint"
#   type        = string
# }

# variable "db_user" {
#   description = "Database username"
#   type        = string
# }

# variable "db_password" {
#   description = "Database password"
#   type        = string
# }

# variable "db_name" {
#   description = "Database name"
#   type        = string
# }

# variable "db_username" {
#   description = "Username for the RDS database"
#   type        = string
# }


# Add CodeStar Connection ARN variable
variable "codestar_connection_arn" {
  description = "ARN of the AWS CodeStar Connection to GitHub"
  type        = string
}
# Terraform configuration for CI/CD pipeline (frontend and backend) using GitHub as source
# Place this in ci-cd/cicd.tf or similar

variable "github_owner" {
  description = "GitHub owner/org name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}