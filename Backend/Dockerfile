# This Dockerfile is for your Node.js backend API

# Use an official Node.js runtime as a parent image
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json (if available)
# The asterisk ensures this works even if package-lock.json isn't present
COPY package.json package-lock.json* ./

# Install only production dependencies
RUN npm install --production

# Bundle the backend app's source code
# This copies server.js and any other files in the Backend dir
COPY . .

# Your server.js listens on process.env.PORT || 3000
EXPOSE 3000

# Define the command to run the app
CMD ["node", "server.js"]
