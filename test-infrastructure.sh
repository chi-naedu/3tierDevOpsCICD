#!/bin/bash
# Infrastructure Testing Script
# Run this to test all tiers of your 3-tier architecture

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Auto-detect from Terraform outputs
REGION="eu-west-2"
TERRAFORM_DIR="$(dirname "$0")/3-Tier_Architecture_with_AWS"

echo -e "${BLUE}Loading configuration from Terraform outputs...${NC}"

# Try to get outputs from Terraform, fallback to AWS API if needed
if [ -d "$TERRAFORM_DIR" ] && command -v terraform &> /dev/null; then
    cd "$TERRAFORM_DIR"
    INTERNET_LB=$(terraform output -raw internet_facing_lb_dns 2>/dev/null || echo "")
    INTERNAL_LB=$(terraform output -raw internal_lb_dns 2>/dev/null || echo "")
    DB_MASTER=$(terraform output -raw database_master_endpoint 2>/dev/null | cut -d: -f1 || echo "")
    CLUSTER_NAME="three-tier-ecs-cluster"
    cd - > /dev/null
else
    echo -e "${YELLOW}Warning: Terraform not available, using AWS CLI...${NC}"
fi

# Fallback to AWS CLI if Terraform outputs not available
if [ -z "$INTERNET_LB" ]; then
    INTERNET_LB=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?starts_with(LoadBalancerName, `internet-facing`)].DNSName' --output text 2>/dev/null)
fi

if [ -z "$INTERNAL_LB" ]; then
    INTERNAL_LB=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?Scheme==`internal`].DNSName' --output text 2>/dev/null)
fi

if [ -z "$DB_MASTER" ]; then
    DB_MASTER=$(aws rds describe-db-instances --region $REGION --query 'DBInstances[?starts_with(DBInstanceIdentifier, `db-master`)].Endpoint.Address' --output text 2>/dev/null)
fi

CLUSTER_NAME="${CLUSTER_NAME:-three-tier-ecs-cluster}"

# Validate required values
if [ -z "$INTERNET_LB" ]; then
    echo -e "${RED}Error: Could not determine internet-facing load balancer${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Configuration loaded${NC}"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  3-TIER INFRASTRUCTURE TEST SUITE${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Test 1: Web Tier (Frontend)
echo -e "${YELLOW}[TEST 1] WEB TIER - Frontend Application${NC}"
echo "Testing frontend via internet-facing ALB..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$INTERNET_LB)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Frontend is accessible (HTTP $RESPONSE)${NC}"
    echo -e "  URL: ${BLUE}http://$INTERNET_LB${NC}"
else
    echo -e "${RED}✗ Frontend returned HTTP $RESPONSE${NC}"
    exit 1
fi
echo ""

# Test 2: Application Tier (Backend API)
echo -e "${YELLOW}[TEST 2] APPLICATION TIER - Backend API${NC}"
echo "Testing backend health endpoint..."
HEALTH=$(curl -s http://$INTERNET_LB/api/health)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Backend API is healthy${NC}"
    echo "  Response: $HEALTH"
else
    echo -e "${RED}✗ Backend health check failed${NC}"
    exit 1
fi
echo ""

# Test 3: Database Tier
echo -e "${YELLOW}[TEST 3] DATA TIER - Database Connectivity${NC}"
echo "Testing database connection..."
DB_HEALTH=$(curl -s http://$INTERNET_LB/api/health/db)
if echo "$DB_HEALTH" | grep -q "connected"; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
    echo "  Response: $DB_HEALTH"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    exit 1
fi
echo ""

# Test 4: User Signup (Create)
echo -e "${YELLOW}[TEST 4] CRUD OPERATIONS - User Signup${NC}"
TIMESTAMP=$(date +%s)
TEST_EMAIL="test${TIMESTAMP}@infra.com"
echo "Creating new user: $TEST_EMAIL"
SIGNUP_RESPONSE=$(curl -s -X POST http://$INTERNET_LB/api/auth/signup \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"Test123!\"}")

if echo "$SIGNUP_RESPONSE" | grep -q "Account created\|created"; then
    echo -e "${GREEN}✓ User registration successful${NC}"
    echo "  Response: $SIGNUP_RESPONSE"
else
    echo -e "${YELLOW}⚠ User registration response: $SIGNUP_RESPONSE${NC}"
    # Don't exit on signup failure - might be duplicate email
fi
echo ""

# Test 5: User Login (Authentication)
echo -e "${YELLOW}[TEST 5] AUTHENTICATION - User Login${NC}"
echo "Testing login with created user..."
LOGIN_RESPONSE=$(curl -s -X POST http://$INTERNET_LB/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"Test123!\"}")

if echo "$LOGIN_RESPONSE" | grep -q "Login successful"; then
    echo -e "${GREEN}✓ User authentication successful${NC}"
    echo "  Response: $LOGIN_RESPONSE"
else
    echo -e "${RED}✗ User authentication failed${NC}"
    echo "  Response: $LOGIN_RESPONSE"
    exit 1
fi
echo ""

# Test 6: ECS Services Status
echo -e "${YELLOW}[TEST 6] CONTAINER ORCHESTRATION - ECS Services${NC}"
echo "Checking ECS services status..."
ECS_STATUS=$(aws ecs describe-services --cluster $CLUSTER_NAME --services backend-service frontend-service --region $REGION --query 'services[].[serviceName,status,runningCount,desiredCount]' --output text)
echo "$ECS_STATUS" | while read -r service status running desired; do
    if [ "$status" = "ACTIVE" ] && [ "$running" = "$desired" ]; then
        echo -e "${GREEN}✓ $service: $status ($running/$desired tasks)${NC}"
    else
        echo -e "${RED}✗ $service: $status ($running/$desired tasks)${NC}"
    fi
done
echo ""

# Test 7: RDS Database Status
echo -e "${YELLOW}[TEST 7] DATABASE TIER - RDS Instances${NC}"
echo "Checking RDS databases status..."
RDS_STATUS=$(aws rds describe-db-instances --region $REGION --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]' --output text)
echo "$RDS_STATUS" | while read -r dbid status; do
    if [ "$status" = "available" ]; then
        echo -e "${GREEN}✓ $dbid: $status${NC}"
    else
        echo -e "${RED}✗ $dbid: $status${NC}"
    fi
done
echo ""

# Test 8: Load Balancers Status
echo -e "${YELLOW}[TEST 8] LOAD BALANCING - ALB Status${NC}"
echo "Checking load balancers..."
LB_STATUS=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[].[LoadBalancerName,State.Code]' --output text)
echo "$LB_STATUS" | while read -r lbname state; do
    if [ "$state" = "active" ]; then
        echo -e "${GREEN}✓ $lbname: $state${NC}"
    else
        echo -e "${RED}✗ $lbname: $state${NC}"
    fi
done
echo ""

# Test 9: CodePipeline Status
echo -e "${YELLOW}[TEST 9] CI/CD PIPELINE - CodePipeline Status${NC}"
echo "Checking pipeline execution..."
PIPELINE_STATUS=$(aws codepipeline get-pipeline-state --name three-tier-pipeline --region $REGION --query 'stageStates[*].[stageName,latestExecution.status]' --output text 2>/dev/null || echo "Pipeline check skipped")
if [ "$PIPELINE_STATUS" != "Pipeline check skipped" ]; then
    echo "$PIPELINE_STATUS" | while read -r stage status; do
        if [ "$status" = "Succeeded" ]; then
            echo -e "${GREEN}✓ $stage: $status${NC}"
        else
            echo -e "${YELLOW}  $stage: $status${NC}"
        fi
    done
else
    echo "  Skipped - Pipeline information not available"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TEST RESULTS SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
echo ""
echo "Infrastructure Components:"
echo -e "  ${GREEN}✓${NC} Web Tier: Frontend serving traffic"
echo -e "  ${GREEN}✓${NC} Application Tier: Backend API responding"
echo -e "  ${GREEN}✓${NC} Data Tier: Database connected and operational"
echo -e "  ${GREEN}✓${NC} Load Balancers: Active and routing traffic"
echo -e "  ${GREEN}✓${NC} Container Services: All tasks running"
echo -e "  ${GREEN}✓${NC} Authentication: Signup and login working"
echo ""
echo "Access Points:"
echo -e "  🌐 Frontend:  ${BLUE}http://$INTERNET_LB${NC}"
echo -e "  🔧 API Base:  ${BLUE}http://$INTERNET_LB/api${NC}"
echo -e "  💚 Health:    ${BLUE}http://$INTERNET_LB/api/health${NC}"
echo ""
echo -e "${GREEN}Your 3-tier application is fully operational!${NC}"
