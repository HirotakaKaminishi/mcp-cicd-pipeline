#!/bin/bash
# Docker Services Setup Script for MCP Server Migration

set -e

echo "🚀 Setting up Docker-based MCP services..."

# Create deployment directory
mkdir -p /var/deployment
cd /var/deployment

# Copy docker-compose configuration
cp /path/to/docker-compose.yml .

# Create required directories
mkdir -p logs/nginx logs/mcp deployment nginx/conf nginx/html

# Copy nginx configuration
cp /path/to/nginx/conf/* nginx/conf/
cp /path/to/nginx/html/* nginx/html/

# Build and start Docker containers
echo "📦 Building Docker images..."
docker-compose build

echo "🔄 Starting Docker services..."
docker-compose up -d

# Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 30

# Health check
echo "🏥 Performing health checks..."
docker-compose ps
docker exec mcp-server curl -f http://localhost:8080 || echo "⚠️ MCP Server not ready yet"
docker exec nginx-proxy curl -f http://localhost || echo "⚠️ Nginx not ready yet"

echo "✅ Docker services setup complete!"
echo "🌐 Services available at:"
echo "  - Main site: http://192.168.111.200"
echo "  - MCP API: http://192.168.111.200:8080"
echo "  - Health: http://192.168.111.200/health"

# Show running containers
echo "📊 Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"