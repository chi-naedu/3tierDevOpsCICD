# This Dockerfile is for your static frontend assets

# Use ECR Public Nginx image to avoid Docker Hub rate limits
FROM public.ecr.aws/nginx/nginx:alpine

# Copy nginx configuration template and entrypoint script
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY entrypoint.sh /entrypoint.sh

# Copy your static files to the default Nginx HTML directory
COPY *.html *.js /usr/share/nginx/html/

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Expose port 80
EXPOSE 80

# Use custom entrypoint for environment variable substitution
ENTRYPOINT ["/entrypoint.sh"]
