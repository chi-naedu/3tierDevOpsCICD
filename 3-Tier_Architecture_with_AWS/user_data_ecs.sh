#!/bin/bash
# Register this EC2 instance with the ECS cluster
echo ECS_CLUSTER=${ecs_cluster_name} >> /etc/ecs/ecs.config
