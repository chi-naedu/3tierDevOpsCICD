# Security group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP for better security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}
# Security Groups Configuration

# Security group for Web Tier Load Balancer
resource "aws_security_group" "alb_web_sg" {
  name        = "alb-web-security-group"
  description = "Security group for web tier load balancer"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-web-sg"
  }
}


# Security group for App Tier Load Balancer
resource "aws_security_group" "alb_app_sg" {
  name        = "alb-app-security-group"
  description = "Security group for app tier load balancer"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
  security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow ECS container instances (including frontend) to access backend on port 5000
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-app-sg"
  }
}


# Security group for RDS Database
resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
  # Removed app_instance_sg as part of ECS migration
  }

  tags = {
    Name = "db-sg"
  }
}