#!/bin/bash

# MCP Server Docker Deployment Script
# Usage: ./scripts/deploy.sh [environment]
# Environment: dev|staging|production (default: production)

set -e

# Configuration
MCP_SERVER_HOST="192.168.111.200"
DEPLOY_PATH="/var/deployment"
SSH_KEY="auth_organized/keys_configs/mcp_docker_key"
ENVIRONMENT="${1:-production}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Check if SSH key exists
check_ssh_key() {
    if [[ ! -f "$SSH_KEY" ]]; then
        error "SSH key not found at $SSH_KEY"
        error "Please run the SSH key setup first:"
        error "  ./auth_organized/keys_configs/setup_ssh_docker.bat"
        exit 1
    fi
    
    # Check SSH key permissions
    chmod 600 "$SSH_KEY" 2>/dev/null || true
    success "SSH key found and permissions set"
}

# Test SSH connection
test_ssh_connection() {
    log "Testing SSH connection to $MCP_SERVER_HOST..."
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$MCP_SERVER_HOST "echo 'SSH connection successful'" > /dev/null 2>&1; then
        success "SSH connection established"
    else
        error "SSH connection failed"
        error "Please check:"
        error "  1. SSH key is properly set up on the server"
        error "  2. Server is accessible at $MCP_SERVER_HOST"
        error "  3. SSH daemon is running on the server"
        exit 1
    fi
}

# Pre-deployment checks
pre_deployment_checks() {
    log "Running pre-deployment checks..."
    
    # Check required files exist
    required_files=("docker-compose.yml" "docker/mcp-server/Dockerfile" "docker/nginx/Dockerfile")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required file missing: $file"
            exit 1
        fi
    done
    
    # Check if React app exists
    if [[ ! -d "03_sample_projects/react_apps" ]]; then
        warning "React app directory not found, creating placeholder"
        mkdir -p 03_sample_projects/react_apps
        echo '{"name": "placeholder", "version": "1.0.0"}' > 03_sample_projects/react_apps/package.json
    fi
    
    success "Pre-deployment checks passed"
}

# Deploy Docker configuration
deploy_docker_config() {
    log "Deploying Docker configuration to server..."
    
    # Copy Docker files
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r docker root@$MCP_SERVER_HOST:/root/ || {
        error "Failed to copy Docker configuration"
        exit 1
    }
    
    # Copy docker-compose.yml
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no docker-compose.yml root@$MCP_SERVER_HOST:$DEPLOY_PATH/ || {
        error "Failed to copy docker-compose.yml"
        exit 1
    }
    
    # Copy React app for volume mount
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r 03_sample_projects/react_apps root@$MCP_SERVER_HOST:/root/ || {
        warning "Failed to copy React app (non-critical)"
    }
    
    success "Docker configuration deployed"
}

# Stop existing services
stop_existing_services() {
    log "Stopping existing services..."
    
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$MCP_SERVER_HOST << 'EOF'
        cd $DEPLOY_PATH
        
        # Stop Docker containers if running
        docker compose down 2>/dev/null || true
        
        # Stop any conflicting host services
        systemctl stop mcp-server nginx 2>/dev/null || true
        pkill -f mcp_server.py 2>/dev/null || true
        pkill -f node 2>/dev/null || true
        
        echo "Existing services stopped"
EOF
    
    success "Existing services stopped"
}

# Build and start Docker containers
build_and_start_containers() {
    log "Building and starting Docker containers..."
    
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$MCP_SERVER_HOST << EOF
        cd $DEPLOY_PATH
        
        # Build containers
        echo "Building Docker images..."
        docker compose build --no-cache
        
        # Start containers
        echo "Starting Docker containers..."
        docker compose up -d
        
        # Wait for services to start
        echo "Waiting for services to initialize..."
        sleep 30
        
        # Check container status
        echo "Container status:"
        docker compose ps
EOF
    
    if [[ $? -eq 0 ]]; then
        success "Docker containers built and started"
    else
        error "Failed to build or start Docker containers"
        exit 1
    fi
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Wait for services to stabilize
    sleep 15
    
    # Test endpoints
    endpoints=(
        "http://$MCP_SERVER_HOST/health"
        "http://$MCP_SERVER_HOST/service"
        "http://$MCP_SERVER_HOST:8080"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -f -s "$endpoint" > /dev/null; then
            success "✅ $endpoint is responding"
        else
            warning "⚠️ $endpoint is not responding"
        fi
    done
    
    # Get detailed status from server
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$MCP_SERVER_HOST << 'EOF'
        echo "=== Final Container Status ==="
        cd $DEPLOY_PATH
        docker compose ps
        
        echo ""
        echo "=== Service Health ==="
        curl -s http://localhost/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Health endpoint not available"
        
        echo ""
        echo "=== MCP Server Status ==="
        curl -s http://localhost:8080 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "MCP server not available"
EOF
}

# Setup auto-start service
setup_autostart() {
    log "Setting up auto-start service..."
    
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no root@$MCP_SERVER_HOST << 'EOF'
        cat > /etc/systemd/system/mcp-docker.service << 'SYSTEMD_EOF'
[Unit]
Description=MCP Docker Compose Service
Requires=docker.service
After=docker.service
StartLimitIntervalSec=0

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DEPLOY_PATH
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF
        
        systemctl daemon-reload
        systemctl enable mcp-docker.service
        echo "Auto-start service configured"
EOF
    
    success "Auto-start service configured"
}

# Main deployment function
main() {
    echo "================================================="
    echo "🐳 MCP Server Docker Deployment Script"
    echo "================================================="
    echo "Environment: $ENVIRONMENT"
    echo "Target: $MCP_SERVER_HOST"
    echo "Deploy Path: $DEPLOY_PATH"
    echo "================================================="
    
    check_ssh_key
    test_ssh_connection
    pre_deployment_checks
    deploy_docker_config
    stop_existing_services
    build_and_start_containers
    verify_deployment
    setup_autostart
    
    echo "================================================="
    success "🎉 Docker deployment completed successfully!"
    echo "================================================="
    echo "📊 Service URLs:"
    echo "  🌐 Main Website: http://$MCP_SERVER_HOST"
    echo "  ❤️  Health Check: http://$MCP_SERVER_HOST/health"
    echo "  🔧 Service Status: http://$MCP_SERVER_HOST/service"  
    echo "  🚀 MCP API: http://$MCP_SERVER_HOST:8080"
    echo "================================================="
}

# Run main function
main "$@"