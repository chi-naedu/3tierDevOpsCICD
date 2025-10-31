# This Dockerfile is for your static frontend assets

# Use ECR Public Nginx image to avoid Docker Hub rate limits
FROM public.ecr.aws/nginx/nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy your static files to the default Nginx HTML directory
COPY *.html *.js /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Nginx will automatically serve index.html on /
CMD ["nginx", "-g", "daemon off;"]
