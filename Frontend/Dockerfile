# This Dockerfile is for your static frontend assets
# Place this file inside your 'Frontend' directory

# Use a lightweight Nginx image to serve static content
FROM nginx:1.25-alpine

# Copy your static files to the default Nginx HTML directory
COPY app.js home.html index.html /usr/share/nginx/html/

# Nginx will automatically serve index.html on /
# and other files (home.html, app.js) as requested.
# The default Nginx configuration (port 80) is sufficient.