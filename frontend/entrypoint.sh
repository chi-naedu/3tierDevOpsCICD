#!/bin/sh

# Set defaults for environment variables if not provided
export API_URL=${API_URL:-"http://internal-backend-alb-123456789.us-east-1.elb.amazonaws.com"}

echo "========================================="
echo "Container starting..."
echo "API_URL environment variable: $API_URL"
echo "========================================="

# Replace API_URL placeholder in nginx configuration
envsubst '${API_URL}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Verify the substitution worked
echo "Generated nginx configuration:"
echo "-----------------------------------------"
cat /etc/nginx/nginx.conf
echo "-----------------------------------------"

# Test nginx configuration
nginx -t

# Start nginx
echo "Starting nginx..."
exec nginx -g "daemon off;"