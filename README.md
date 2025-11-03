# 3-Tier AWS DevOps Project with CI/CD

Production-ready 3-tier web application on AWS with Terraform IaC and automated CI/CD pipeline.

---

## 🎯 Overview

**3-Tier Architecture:**
- **Web Tier**: Nginx frontend via internet-facing ALB
- **Application Tier**: Node.js/Express API on ECS containers
- **Database Tier**: MySQL RDS with master-slave replication

**Key Stats:**
- ✅ Cross-AZ deployment (eu-west-2a/b)
- ✅ Automated CI/CD (5-stage pipeline)
- ✅ Secrets management (AWS SSM & Secrets Manager)

---

## 🏗️ Architecture

```
Internet → Internet-Facing ALB (Public) → Frontend (ECS/Nginx) 
→ Internal ALB (Private) → Backend (ECS/Node.js) → RDS MySQL (Master/Slave)
```

**Network:** VPC (10.0.0.0/16), Public Subnets (10.0.1-2.0/24), Private Subnets (10.0.3-4.0/24)  
**Availability:** Multi-AZ across eu-west-2a and eu-west-2b  
**Access:** Bastion host for secure SSH to private resources

---

## ✨ Features

**Infrastructure:** Multi-AZ, Auto-scaling ECS, Load balancing, DB replication, Private networking  
**Application:** JWT auth, RESTful API, User/task management, Health monitoring  
**DevOps:** Terraform IaC, CI/CD pipeline, Docker containers, ECR registry, CloudWatch logging  
**Security:** Security groups, Private subnets, Encrypted storage, Secrets management, IAM least privilege


---

## 📂 Project Structure

```
DevOpsProject/
├── 3-Tier_Architecture_with_AWS/      # Terraform IaC
│   ├── main.tf                   # AWS provider configuration
│   ├── variables.tf                   # Input variables
│   ├── terraform.tfvars               # Variable values (gitignored)
│   ├── networking.tf                  # VPC, subnets, IGW, NAT
│   ├── security_groups.tf             # Security group rules
│   ├── webtier.tf                     # Internet-facing ALB
│   ├── apptier.tf                     # Internal ALB
│   ├── ecs.tf                         # ECS cluster, services, tasks
│   ├── datatier.tf                    # RDS MySQL master/slave
│   ├── bastion.tf                     # Bastion host
│   ├── cicd.tf                        # CodePipeline & CodeBuild
│   └── outputs.tf                     # Output values
│
├── backend/                           # Node.js API
│   ├── server.js                      # Express app with routes
│   ├── package.json                   # Node dependencies
│   ├── Dockerfile                     # Backend container image
│   └── .dockerignore                  # Exclude files from image
│
├── frontend/                          # Static web frontend
│   ├── index.html                     # Main HTML page
│   ├── styles.css                     # CSS styling
│   ├── script.js                      # Client-side JavaScript
│   ├── nginx.conf                     # Nginx configuration
│   ├── Dockerfile                     # Frontend container image
│   └── .dockerignore                  # Exclude .git from image
│
├── database/                          # database setup
```


---

## 🚀 Quick Start

```bash
# 1. Clone & configure
git clone https://github.com/elizabethajala99-ai/DevOpsProject.git
cd DevOpsProject/3-Tier_Architecture_with_AWS

# 2. Create terraform.tfvars
cat > terraform.tfvars << 'EOF'
aws_region     = "eu-west-2"
aws_account_id = "YOUR_ACCOUNT_ID"
environment    = "production"

github_repo                = "DevOpsProject"
github_repo_owner          = "YOUR_GITHUB_USERNAME"
github_branch              = "main"
codestar_connection_arn    = "YOUR_CODESTAR_CONNECTION_ARN"

db_name           = "mydatabase"
db_username       = "mydbuser"
db_password       = "YourSecurePassword123!"
db_slave_password = "YourSecurePassword123!"

jwt_secret = "your-super-secret-jwt-key-min-32-chars"
key_name   = "your-ec2-keypair"
EOF

# 3. Deploy
terraform init
terraform plan
terraform apply

# 4. Get application URL
terraform output internet_facing_lb_dns
```


---

## 🔧 Deployment

```bash
cd 3-Tier_Architecture_with_AWS
terraform init
terraform plan
terraform apply

# Get outputs
terraform output
```

**Key Outputs:**
- `internet_facing_lb_dns` - Frontend URL
- `bastion_host_public_ip` - Bastion SSH access
- `database_master_endpoint` - RDS master
- `database_slave_endpoint` - RDS replica
- `internal_lb_dns` - Backend API (internal)

---

## 🧪 Testing

```bash
./test-infrastructure.sh
```

**Tests:** Frontend accessibility, Backend health, Database connection, User signup/login, ECS services, RDS availability, Load balancers, CI/CD pipeline status.

---

## 🔐 Access & Management

**Frontend Application:**
```bash
terraform output -raw internet_facing_lb_dns
# Access at: http://<lb-dns>
```

**Database Access (via Bastion):**
```bash
BASTION_IP=$(terraform output -raw bastion_host_public_ip)
ssh -i /path/to/keypair.pem ec2-user@$BASTION_IP

# Install MySQL client and connect
sudo yum install -y mariadb
mysql -h <db-endpoint> -u mydbuser -p mydatabase
```
---

## 🔒 Security

| Feature | Implementation |
|---------|---------------|
| Network Isolation | VPC with public/private subnets across 3 AZs |
| Access Control | Security groups with least-privilege rules |
| Encryption | RDS encryption at rest, HTTPS in transit |
| Secrets | AWS Secrets Manager + SSM Parameter Store |
| Database Access | Bastion host in public subnet only |

---

## 🔄 CI/CD Pipeline

**Trigger:** Push to `main` branch

**Stages:** Source (GitHub) → Build (CodeBuild) → Deploy (ECS)

**Build Specs:** `buildspec-frontend.yml`, `buildspec-backend.yml`

**Artifacts:** Docker images → ECR → ECS services

**Monitor Pipeline:**
```bash
aws codepipeline get-pipeline-state --name three-tier-app-pipeline
```

---

## 📊 Monitoring

**CloudWatch Logs:**
```bash
aws logs tail /ecs/frontend --follow
aws logs tail /ecs/backend --follow
```

**CloudWatch Dashboard:**
```bash
aws cloudwatch get-dashboard --dashboard-name three-tier-app-dashboard
```

**Key Metrics:** ECS CPU/Memory, ALB request count, RDS connections, target health

---

## 🧹 Cleanup

```bash
cd 3-Tier_Architecture_with_AWS
terraform destroy
```

**Note:** Secrets Manager secrets have 7-day deletion window. Use `--force-delete-without-recovery` to delete immediately if recreating infrastructure.

---

## 📝 Notes

- **Deployment Method:** Direct ECS (not CodeDeploy), so `appspec.yml` files are unused
- **Database:** Master-slave replication with automatic failover
- **Auto-scaling:** Configured for frontend and backend ECS services
- **Secrets:** Managed via AWS Secrets Manager, never hardcoded
- **Total Resources:** ~98 AWS resources deployed

---

### Pipeline Stages
1. **Source**: Monitors GitHub repository via CodeStar Connection
2. **Build-Frontend**: Builds frontend Docker image, pushes to ECR
3. **Build-Backend**: Builds backend Docker image, pushes to ECR
4. **Deploy-Frontend**: Updates ECS frontend service
5. **Deploy-Backend**: Updates ECS backend service

### Buildspec Files
- `3-Tier_Architecture_with_AWS/ci-cd/buildspec-frontend.yml`
- `3-Tier_Architecture_with_AWS/ci-cd/buildspec-backend.yml`

### Triggering a Deployment
```bash
# Make code changes
git add .
git commit -m "Update feature"
git push origin main

# Pipeline automatically triggers
# Monitor pipeline
aws codepipeline get-pipeline-state \
  --name three-tier-pipeline \
  --region eu-west-2
```

### Manual Deployment
```bash
# Force new ECS deployment
aws ecs update-service \
  --cluster three-tier-ecs-cluster \
  --service backend-service \
  --force-new-deployment \
  --region eu-west-2
```

---

## 📊 Monitoring

### CloudWatch Logs
- **Backend Logs**: `/ecs/backend`
- **Frontend Logs**: `/ecs/frontend`

### Key Metrics to Monitor
- ECS CPU/Memory utilization
- ALB request count and latency
- RDS connections and queries
- Target health status

### Viewing Metrics
```bash
# ECS service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=backend-service \
  --start-time 2025-10-31T00:00:00Z \
  --end-time 2025-10-31T23:59:59Z \
  --period 3600 \
  --statistics Average \
  --region eu-west-2

# ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/internet-facing-lb/xxx \
  --start-time 2025-10-31T00:00:00Z \
  --end-time 2025-10-31T23:59:59Z \
  --period 300 \
  --statistics Average \
  --region eu-west-2
```


---


```

### Cost Considerations
Running this infrastructure costs approximately:
- **ECS (EC2 instances)**: ~$20-30/month
- **RDS (db.t3.micro x2)**: ~$30-40/month
- **NAT Gateway**: ~$32/month
- **ALB**: ~$16/month
- **Total**: ~$100-120/month

**Tip**: Stop/terminate resources when not in use to save costs.

---

## 📈 Future Enhancements

### Planned Improvements
- [ ] **HTTPS/SSL**: Add SSL certificate to ALB
- [ ] **Auto-Scaling**: Configure ECS auto-scaling policies
- [ ] **CloudWatch Alarms**: Set up monitoring alerts
- [ ] **WAF**: Add Web Application Firewall
- [x] **Secrets Manager**: Credentials secured with AWS SSM & Secrets Manager
- [ ] **Multi-Region**: Deploy to multiple regions for DR
- [ ] **CDN**: Add CloudFront for static assets
- [ ] **Backup Automation**: Automated RDS snapshots
- [ ] **Cost Optimization**: Reserved instances, spot instances



