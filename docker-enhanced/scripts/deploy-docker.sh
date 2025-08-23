#!/bin/bash
# Docker Deployment Script for MCP Server

set -e

echo "🚀 Starting Docker Deployment..."

# Create deployment directory
echo "📁 Creating deployment directories..."
mkdir -p /var/deployment
cd /var/deployment

# Copy Docker Compose and related files
echo "📋 Setting up Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  mcp-server:
    image: mcp-server:latest
    container_name: mcp-server
    ports:
      - "8080:8080"
    volumes:
      - ./logs:/var/log/mcp
      - ./deployment:/var/deployment
    networks:
      - mcp-network
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
    environment:
      - MCP_SERVER_PORT=8080
      - NODE_ENV=production

  nginx:
    image: nginx-proxy:latest
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf:/etc/nginx/conf.d
      - ./nginx/html:/usr/share/nginx/html
      - ./logs/nginx:/var/log/nginx
    networks:
      - mcp-network
    restart: always
    depends_on:
      - mcp-server
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

  react-app:
    image: react-app:latest
    container_name: react-app
    ports:
      - "3000:3000"
    volumes:
      - ./react_apps:/app
      - node_modules:/app/node_modules
    networks:
      - mcp-network
    restart: always
    environment:
      - NODE_ENV=development
      - VITE_MCP_SERVER_URL=http://mcp-server:8080
    depends_on:
      - mcp-server

networks:
  mcp-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

volumes:
  node_modules:
    driver: local
  nginx_logs:
    driver: local
  mcp_logs:
    driver: local
EOF

# Create necessary directories
mkdir -p logs/nginx logs/mcp deployment nginx/conf nginx/html react_apps

# Start existing MCPサーバー temporarily
echo "🔄 Starting temporary MCP server..."
systemctl start mcp-server || true
sleep 5

# Build Docker images
echo "📦 Building Docker images..."
docker compose build

# Stop old services
echo "🛑 Stopping old services..."
systemctl stop nginx || true
systemctl stop mcp-server || true
systemctl disable nginx || true
systemctl disable mcp-server || true

# Start Docker Compose
echo "🐳 Starting Docker containers..."
docker compose up -d

# Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 30

# Health check
echo "🏥 Performing health checks..."
docker compose ps

# Check container health
echo "🔍 Checking container status..."
docker exec mcp-server curl -f http://localhost:8080 && echo "✅ MCP Server is healthy" || echo "⚠️ MCP Server not ready"
docker exec nginx-proxy curl -f http://localhost && echo "✅ Nginx is healthy" || echo "⚠️ Nginx not ready"

# Enable auto-start on boot
echo "🔧 Enabling auto-start on system boot..."
cat > /etc/systemd/system/docker-compose.service << 'EOF'
[Unit]
Description=Docker Compose Application Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/var/deployment
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker-compose.service

echo "✅ Docker deployment complete!"
echo "🌐 Services available at:"
echo "  - Main site: http://192.168.111.200"
echo "  - MCP API: http://192.168.111.200:8080"
echo "  - React App: http://192.168.111.200:3000"

# Show running containers
echo "📊 Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"