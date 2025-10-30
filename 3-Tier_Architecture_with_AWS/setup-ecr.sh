#!/bin/bash
# This script creates ECR repositories for frontend and backend if they do not exist
# Usage: bash setup-ecr.sh

AWS_REGION=${AWS_REGION:-eu-west-2}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

for repo in frontend-repo backend-repo; do
  if ! aws ecr describe-repositories --repository-names $repo --region $AWS_REGION >/dev/null 2>&1; then
    echo "Creating ECR repository: $repo"
    aws ecr create-repository --repository-name $repo --region $AWS_REGION
  else
    echo "ECR repository $repo already exists."
  fi
done
