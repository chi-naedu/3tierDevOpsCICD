#!/bin/bash
# ECS cluster name must be passed in via templatefile or env var
if [ -z "$ECS_CLUSTER_NAME" ]; then
  echo "ECS_CLUSTER_NAME not set, using default: three-tier-ecs-cluster"
  ECS_CLUSTER_NAME="three-tier-ecs-cluster"
fi

echo "ECS_CLUSTER=$ECS_CLUSTER_NAME" >> /etc/ecs/ecs.config
