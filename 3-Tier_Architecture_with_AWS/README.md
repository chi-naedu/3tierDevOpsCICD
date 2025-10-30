# 3-Tier Architecture with AWS

This project implements a secure, scalable three-tier architecture on AWS using Terraform. The architecture consists of web, application, and database tiers distributed across multiple availability zones for high availability.

## Prerequisites
- AWS Account
- Terraform installed in VS Code
- AWS CLI configured
- SSH key pair for EC2 instances

## Architecture Overview

### Network Layer
- VPC with CIDR: 10.0.0.0/16
- 4 Subnets across 2 Availability Zones in eu-west-2:
  - Public Subnets (10.0.1.0/24, 10.0.2.0/24) for ALB and bastion
  - Private Subnets (10.0.3.0/24, 10.0.4.0/24) for app, web, and database tiers
- NAT Gateway in public subnet 2 (eu-west-2b) for private subnet internet access
- Internet Gateway for public subnet internet access

### Web Tier (Private)
- Internet-facing Application Load Balancer in public subnets:
  * Accepts HTTP/HTTPS from internet via Internet Gateway
  * Routes traffic to web instances
- Auto Scaling Group with EC2 instances in private subnets:
  * Only accepts traffic from the ALB
  * No direct internet access (all through ALB)
- Minimum 2, Maximum 4 instances

### Application Tier (Private)
- Internal Application Load Balancer
- Auto Scaling Group with EC2 instances
- Located in private subnets
- Python web server running on port 8080
- Accessible only through internal ALB

### Database Tier (Private)
- RDS MySQL 8.0 with master-slave replication
- Master instance in private subnet 1 (eu-west-2a)
- Read replica in private subnet 2 (eu-west-2b)
- Encrypted storage using AWS KMS
- Parameter group configured for UTF-8 encoding

### Security
- Bastion host in public subnet 1 for secure SSH admin access
- Application Load balancer in public subnet directs requests to autoscaling group in private subnet
- All application components (web, app, database) in private subnets
- Network ACLs for additional security
- Encrypted root volumes for all instances
- Security groups with least privilege access controlling traffic between tiers:
   - Web tier: Allows HTTP/HTTPS from internet
   - App tier: Allows traffic only from web tier
   - Database: Allows traffic only from app tier
   - Bastion: Allows SSH from approved IPs

### High Availability
- Components distributed across two Availability Zones
- Auto Scaling Groups for frontend and backend
- Database replication across AZs
- Load balancers for traffic distribution

## Project Structure
```
.
├── apptier.tf          # Application tier configuration
├── bastion.tf         # Bastion host configuration
├── datatier.tf        # Database tier configuration
├── networking.tf      # VPC and network configuration
├── outputs.tf         # Output values
├── providers.tf       # AWS provider configuration
├── security_groups.tf # Security group configurations
├── variables.tf       # Input variables
└── webtier.tf        # Web tier configuration
```

## Variables
Important variables that need to be set:
- `aws_region`: AWS region (default: eu-west-2)
- `instance_type`: EC2 instance type (default: t3.micro)
- `key_pair_name`: SSH key pair name
- `db_name`: Database name
- `db_username`: Database username
- `db_password`: Database password
  
## Usage
1. Clone the repository
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Review the plan:
   ```bash
   terraform plan
   ```
4. Apply the configuration:
   ```bash
   terraform apply
   ```
5. Destroy Infrastructure:
   ```bash
   terraform destroy
   ```

## Testing the Infrastructure

### 1. Connecting to Bastion Host
```bash
ssh -i cba_keypair.pem ec2-user@<bastion-public-ip>
```

### 2. Testing Web Tier
Copy your internet-facing load balancer DNS Link
```bash
#Open in web browser:
http://internet-facing-lb-xxx.eu-west-2.elb.amazonaws.com
```

From bastion host:
```bash
# Or SSH to web instances
ssh -i ~/.ssh/cba_keypair.pem ec2-user@<web-instance-private-ip>
```

### 3. Testing Application Tier
From bastion host:
```bash
# Test internal ALB
curl internal-app-internal-lb-xxx.eu-west-2.elb.amazonaws.com:8080/app.html

# SSH to app instances
ssh -i cba_keypair.pem ec2-user@<app-instance-private-ip>
```

### 4. Testing Database Tier
From app instances:
```bash
# Connect to master (read/write)
mysql -h database-master.xxx.eu-west-2.rds.amazonaws.com -u mydb -p

# Connect to slave (read-only)
mysql -h database-slave.xxx.eu-west-2.rds.amazonaws.com -u mydb -p
```

## Important Notes
1. Web tier instances only accept HTTP traffic from the internet-facing ALB
2. App tier is only accessible through internal ALB
3. Database slave is read-only
4. All instances use t3.micro instance type
5. RDS instances are encrypted at rest
6. Proper master-slave replication is configured for the database

## Access and Management
- Administrative access via bastion host
- Database management through backend tier
- Monitoring through CloudWatch (optional)
- Load balancer health checks enabled
- Auto scaling based on demand

## Deployment Verification and Testing Guide

### Successfully Tested Components
1. Infrastructure Deployment
   - All resources successfully created with `terraform apply`
   - VPC, subnets, and networking components verified
   - All instances and services properly launched

2. Bastion Host Access
   - SSH access confirmed using: `ssh -i cba_keypair.pem ec2-user@<bastion-public-ip>`
   - Key file transfer verified using: `scp -i cba_keypair.pem cba_keypair.pem ec2-user@<bastion-host>:/home/ec2-user/`

3. Database Layer
   - MariaDB successfully installed on required instances
   - Database connectivity verified from application tier
   - Master-slave replication confirmed operational

4. Security Verification
   - Private instances not accessible from internet
   - Security group rules functioning as expected
   - Bastion host acting as secure gateway

### Practical Tips
1. File Permissions
   - Remember to chmod 400 your key file: `chmod 400 cba_keypair.pem`
   - For editing system files, use sudo (e.g., `sudo nano index.html`)

2. SSH Access Pattern
   - First SSH to bastion host
   - Then SSH to private instances from bastion
   - Keep key file secure and never share it

3. Database Management
   - Use MariaDB/MySQL client tools for database operations
   - Always connect to database from application tier instances
   - Follow principle of least privilege for database users

## Best Practices Implemented
1. Security in layers (defense in depth)
2. Separation of concerns between tiers
3. High availability across AZs
4. Scalable architecture
5. Least privilege access controls
6. Private subnet protection
7. Read/Write separation for database
8. Verified and tested deployment procedures
