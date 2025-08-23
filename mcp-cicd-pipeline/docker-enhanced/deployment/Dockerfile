FROM node:18-alpine

# Install required system packages
RUN apk add --no-cache \
    curl \
    git \
    docker-cli \
    docker-compose \
    python3 \
    py3-pip \
    bash \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy deployment tools
COPY package*.json ./
RUN npm install

# Copy deployment scripts
COPY . .

# Install Python packages for MCP communication (bypass externally-managed-environment)
RUN pip3 install --break-system-packages requests

# Make scripts executable
RUN chmod +x /app/*.js /app/*.sh

# Create deployment directories
RUN mkdir -p /var/deployment /var/log/deployment /deployment_tools

# Create non-root user
RUN addgroup -g 1001 -S deployment
RUN adduser -S deployuser -u 1001
RUN chown -R deployuser:deployment /app /var/deployment /var/log/deployment

USER deployuser

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://mcp-server:8080 || exit 1

# Keep container running
CMD ["tail", "-f", "/dev/null"]