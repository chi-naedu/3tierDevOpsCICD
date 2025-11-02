# 1. Creates the secret "container"
resource "aws_secretsmanager_secret" "datab_password" {
  name = "db-secret-v2" # Sets the name you'll see in the AWS console
}

# 2. Creates a version of the secret with the actual password value
resource "aws_secretsmanager_secret_version" "datab_password" {
  secret_id = aws_secretsmanager_secret.datab_password.id
  secret_string = random_password.db_password.result
}

resource "random_password" "db_password" {
  length  = 16
  special = true
  # Do not use '$' as it was causing the original error
  override_special = "!#%&()*+,-.:;<=>?[]^_`{|}~"
}

