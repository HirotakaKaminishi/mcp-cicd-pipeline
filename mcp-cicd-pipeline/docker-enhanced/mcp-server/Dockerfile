FROM python:3.9-alpine

# Install required system packages including build dependencies for psutil
RUN apk add --no-cache \
    curl \
    git \
    openssh-client \
    docker-cli \
    docker-compose \
    nodejs \
    npm \
    procps \
    gcc \
    musl-dev \
    linux-headers \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy MCP server files
COPY . /app/

# Create required directories
RUN mkdir -p /var/log/mcp /var/deployment

# Install Python dependencies
RUN pip install --no-cache-dir requests psutil

# Copy MCP server script
COPY mcp_server_extended.py /app/mcp_server_extended.py

# Make sure the script is executable
RUN chmod +x /app/mcp_server_extended.py

# Expose MCP server port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080 || exit 1

# Start MCP server
CMD ["python3", "/app/mcp_server_extended.py"]