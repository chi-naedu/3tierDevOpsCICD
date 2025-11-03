# SSM Parameter Store and Secrets Manager Configuration
# This file manages secure storage and retrieval of application secrets

# Data sources for AWS account information
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ========================================
# SSM Parameter Store (Non-sensitive configuration)
# ========================================

resource "aws_ssm_parameter" "database_host" {
  name  = "/myapp/database/host"
  type  = "String"
  value = aws_db_instance.database_master.address
  
  description = "RDS master database endpoint"

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "database"
  }
}

resource "aws_ssm_parameter" "database_username" {
  name  = "/myapp/database/username"
  type  = "String"
  value = var.db_username
  
  description = "Database username for application"

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "database"
  }
}

resource "aws_ssm_parameter" "database_name" {
  name  = "/myapp/database/name"
  type  = "String"
  value = var.db_name
  
  description = "Database name for application"

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "database"
  }
}

resource "aws_ssm_parameter" "database_port" {
  name  = "/myapp/database/port"
  type  = "String"
  value = "3306"
  
  description = "Database port"

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "database"
  }
}

resource "aws_ssm_parameter" "frontend_api_url" {
  name  = "/myapp/frontend/api-url"
  type  = "String"
  value = "http://${aws_lb.internal_lb.dns_name}:5000"
  
  description = "Internal API URL for frontend to connect to backend"

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "frontend"
  }
}

resource "aws_ssm_parameter" "app_environment" {
  name  = "/myapp/app/environment"
  type  = "String"
  value = var.environment
  
  description = "Application environment (production, staging, development)"

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "application"
  }
}

# ========================================
# AWS Secrets Manager (Sensitive data)
# ========================================

resource "aws_secretsmanager_secret" "database_password" {
  name                    = "/myapp/database/master-password"
  description             = "Master database password for 3-tier application"
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "database"
  }
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = var.db_password
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "/myapp/jwt/secret"
  description             = "JWT signing secret for authentication"
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "authentication"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}

# Optional: Database slave password (if different from master)
resource "aws_secretsmanager_secret" "database_slave_password" {
  name                    = "/myapp/database/slave-password"
  description             = "Slave database password for read replicas"
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
    Component   = "database"
  }
}

resource "aws_secretsmanager_secret_version" "database_slave_password" {
  secret_id     = aws_secretsmanager_secret.database_slave_password.id
  secret_string = var.db_slave_password # Using different password for security
}

# ========================================
# KMS Key for additional encryption
# ========================================

resource "aws_kms_key" "parameter_store_key" {
  description             = "KMS key for SSM Parameter Store encryption"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.environment}-parameter-store-key"
    Environment = var.environment
    Project     = "3tier-app"
  }
}

resource "aws_kms_alias" "parameter_store_key_alias" {
  name          = "alias/${var.environment}-parameter-store-key"
  target_key_id = aws_kms_key.parameter_store_key.key_id
}

# ========================================
# IAM Policies for ECS Tasks
# ========================================

# IAM Policy for ECS Task Execution Role to access SSM Parameters
resource "aws_iam_policy" "production_ecs_ssm_access_policy" {
  name        = "production-ecs-task-execution-ssm-access-policy"
  description = "Policy for ECS task execution role to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/myapp/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          aws_kms_key.parameter_store_key.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "production-ecs-task-execution-ssm-access-policy"
    Environment = var.environment
    Project     = "3tier-app"
  }
}

# IAM Policy for ECS Task Execution Role to access Secrets Manager
resource "aws_iam_policy" "production_ecs_secrets_manager_access_policy" {
  name        = "production-ecs-task-execution-secrets-manager-access-policy"
  description = "Policy for ECS task execution role to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.database_password.arn,
          aws_secretsmanager_secret.database_slave_password.arn,
          aws_secretsmanager_secret.jwt_secret.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          aws_kms_key.parameter_store_key.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "production-ecs-task-execution-secrets-manager-access-policy"
    Environment = var.environment
    Project     = "3tier-app"
  }
}

# IAM Policy for ECS Task Execution Role to access SSM Parameters
resource "aws_iam_role_policy_attachment" "ecs_task_execution_ssm_policy" {
  policy_arn = aws_iam_policy.production_ecs_ssm_access_policy.arn
  role       = aws_iam_role.ecs_task_execution.name
}

# IAM Policy for ECS Task Execution Role to access Secrets Manager
resource "aws_iam_role_policy_attachment" "ecs_task_execution_secrets_policy" {
  policy_arn = aws_iam_policy.production_ecs_secrets_manager_access_policy.arn
  role       = aws_iam_role.ecs_task_execution.name
}

# ========================================
# IAM Policy for Bastion Host (Optional)
# ========================================

resource "aws_iam_role" "bastion_role" {
  name = "${var.environment}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
  }
}

resource "aws_iam_policy" "bastion_secrets_access" {
  name        = "${var.environment}-bastion-secrets-access"
  description = "Policy for bastion host to access secrets for troubleshooting"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/myapp/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.database_password.arn,
          aws_secretsmanager_secret.database_slave_password.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_secrets_access" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bastion_secrets_access.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.environment}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# ========================================
# CloudWatch Monitoring
# ========================================

# CloudWatch alarm for excessive secret access
resource "aws_cloudwatch_metric_alarm" "secrets_access_alarm" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.environment}-high-secrets-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfSecrets"
  namespace           = "AWS/SecretsManager"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors excessive secrets access"
  
  tags = {
    Environment = var.environment
    Project     = "3tier-app"
  }
}

# EventBridge rule for parameter changes
resource "aws_cloudwatch_event_rule" "parameter_change" {
  count = var.enable_monitoring ? 1 : 0

  name        = "${var.environment}-parameter-change-rule"
  description = "Capture parameter changes"

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["Parameter Store Change"]
    detail = {
      name = ["/myapp/*"]
    }
  })

  tags = {
    Environment = var.environment
    Project     = "3tier-app"
  }
}

# ========================================
# Outputs
# ========================================

output "ssm_parameters" {
  description = "Map of SSM parameter names and ARNs"
  value = {
    database_host        = aws_ssm_parameter.database_host.arn
    database_username    = aws_ssm_parameter.database_username.arn
    database_name        = aws_ssm_parameter.database_name.arn
    database_port        = aws_ssm_parameter.database_port.arn
    frontend_api_url     = aws_ssm_parameter.frontend_api_url.arn
    app_environment      = aws_ssm_parameter.app_environment.arn
  }
}

output "secrets_manager_secrets" {
  description = "Map of Secrets Manager secret names and ARNs"
  value = {
    database_password       = aws_secretsmanager_secret.database_password.arn
    database_slave_password = aws_secretsmanager_secret.database_slave_password.arn
    jwt_secret             = aws_secretsmanager_secret.jwt_secret.arn
  }
  sensitive = true
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for parameter encryption"
  value       = aws_kms_key.parameter_store_key.arn
}

output "bastion_instance_profile_name" {
  description = "Name of the IAM instance profile for bastion host"
  value       = aws_iam_instance_profile.bastion_profile.name
}