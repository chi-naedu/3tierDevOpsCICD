# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "three-tier-ecs-cluster"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definitions (example for backend)
resource "aws_ecs_task_definition" "backend" {
  family                   = "backend-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 5000, hostPort = 5000 }]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_USER", value = var.db_user },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "DB_NAME", value = var.db_name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/backend"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Service (example for backend)
resource "aws_ecs_service" "backend" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "EC2"
  
  health_check_grace_period_seconds = 600
  
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  
  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }
  
  # For EC2 launch type, networking is handled by the EC2 instances (container instances)
  load_balancer {
    target_group_arn = aws_lb_target_group.internal_tg.arn
    container_name   = "backend"
    container_port   = 5000
  }
  
  depends_on = [aws_lb_listener.internal_listener]
}

# ECS Task Definition for Frontend
resource "aws_ecs_task_definition" "frontend" {
  family                   = "frontend-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:latest"
      essential = true
      portMappings = [{ containerPort = 80, hostPort = 80 }]
      environment = [
        { name = "NODE_ENV", value = "production" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/frontend"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Service for Frontend
resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "EC2"
  
  health_check_grace_period_seconds = 600
  
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  
  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.internet_facing_tg.arn
    container_name   = "frontend"
    container_port   = 80
  }
  
  depends_on = [aws_lb_listener.internet_facing_listener]
}

# ECS Container Instance IAM Role
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume_role_policy.json
}

data "aws_iam_policy_document" "ecs_instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# ECS Container Instance Launch Template
resource "aws_launch_template" "ecs" {
  name_prefix   = "ecs-container-"
  image_id      = data.aws_ami.ecs.id
  instance_type = var.ecs_instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }
  user_data = base64encode(templatefile("user_data_ecs.sh", {
    ecs_cluster_name = aws_ecs_cluster.main.name
  }))
  vpc_security_group_ids = [aws_security_group.ecs_instance_sg.id]
  key_name = var.key_name
}

data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["591542846629"] # Amazon ECS AMI owner
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# ECS Container Instance Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                      = "ecs-container-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "ecs-container-instance"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

#C
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/frontend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/backend"
  retention_in_days = 7
}

# user_data_ecs.sh template (create this file in the same directory):
# #!/bin/bash
# echo ECS_CLUSTER=${ecs_cluster_name} >> /etc/ecs/ecs.config
