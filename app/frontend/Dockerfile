# Use a Node.js 18 image compatible with react-scripts 4
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Enable legacy OpenSSL provider for older webpack/react-scripts builds
ENV NODE_OPTIONS=--openssl-legacy-provider

# Copy the package.json and package-lock.json files to the container
COPY package*.json ./

# Install the application's dependencies inside the container
RUN npm install

# Copy the rest of the application code to the container
COPY . .

# Specify the command to run when the container starts
CMD [ "npm", "start" ]
