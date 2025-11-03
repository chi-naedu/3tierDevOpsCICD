#!/bin/bash

# Update the system
yum update -y

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install MySQL client
yum install -y mysql

# Install jq for JSON parsing
yum install -y jq

# Install Session Manager plugin for AWS CLI
yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm

# Create helper scripts for accessing secrets
cat > /home/ec2-user/get-db-password.sh << 'EOF'
#!/bin/bash
aws secretsmanager get-secret-value \
  --secret-id "/myapp/database/master-password" \
  --region eu-west-2 \
  --query SecretString \
  --output text
EOF

cat > /home/ec2-user/get-db-host.sh << 'EOF'
#!/bin/bash
aws ssm get-parameter \
  --name "/myapp/database/host" \
  --region eu-west-2 \
  --query Parameter.Value \
  --output text
EOF

cat > /home/ec2-user/connect-to-db.sh << 'EOF'
#!/bin/bash
DB_HOST=$(aws ssm get-parameter --name "/myapp/database/host" --region eu-west-2 --query Parameter.Value --output text)
DB_USER=$(aws ssm get-parameter --name "/myapp/database/username" --region eu-west-2 --query Parameter.Value --output text)
DB_NAME=$(aws ssm get-parameter --name "/myapp/database/name" --region eu-west-2 --query Parameter.Value --output text)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "/myapp/database/master-password" --region eu-west-2 --query SecretString --output text)

echo "Connecting to database: $DB_HOST"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME"
EOF

# Make scripts executable
chmod +x /home/ec2-user/*.sh
chown ec2-user:ec2-user /home/ec2-user/*.sh

# Create a welcome message with usage instructions
cat > /etc/motd << 'EOF'
=======================================================
   AWS 3-Tier Architecture - Bastion Host
=======================================================

This bastion host has access to SSM Parameter Store and 
Secrets Manager. Use the following commands:

Database Connection:
  ./connect-to-db.sh              - Connect to MySQL database
  ./get-db-host.sh               - Get database host
  ./get-db-password.sh           - Get database password

SSM Parameter Store:
  aws ssm get-parameter --name "/myapp/database/host" --region eu-west-2
  aws ssm get-parameters-by-path --path "/myapp" --region eu-west-2

Secrets Manager:
  aws secretsmanager list-secrets --region eu-west-2
  aws secretsmanager get-secret-value --secret-id "/myapp/database/master-password" --region eu-west-2

=======================================================
EOF

echo "Bastion host setup completed" > /var/log/user-data.log