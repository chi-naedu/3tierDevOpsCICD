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

  # Allow MySQL access from ECS container instances
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instance_sg.id]
    description     = "Allow MySQL from ECS instances"
  }

  # Allow MySQL access from bastion for administration
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow MySQL from bastion"
  }

  tags = {
    Name = "db-sg"
  }
}

# Security group for ECS Container Instances
resource "aws_security_group" "ecs_instance_sg" {
  name        = "ecs-instance-security-group"
  description = "Security group for ECS container instances"
  vpc_id      = aws_vpc.main_vpc.id

  # Allow traffic from web ALB to frontend containers (port 80)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_web_sg.id]
  }

  # Allow traffic from internal ALB to backend containers (port 5000)
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_app_sg.id]
  }

  # Allow SSH from bastion (optional)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow all outbound traffic (for pulling images from ECR, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-instance-sg"
  }
}

# Separate rule to allow ECS instances to reach internal ALB (avoids circular dependency)
resource "aws_security_group_rule" "alb_app_from_ecs" {
  type                     = "ingress"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb_app_sg.id
  source_security_group_id = aws_security_group.ecs_instance_sg.id
  description              = "Allow ECS instances (frontend containers) to access internal ALB"
}
