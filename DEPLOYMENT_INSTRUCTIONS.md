# 🐳 Docker Deployment Instructions

## 🔧 Prerequisites
- SSH access to MCP Server (192.168.111.200)
- Docker and Docker Compose installed on server
- New SSH key configured

## 📋 Deployment Steps

### 1. SSH Key Setup (First Time Only)
```bash
# Run the SSH key setup script
C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\setup_ssh_docker.bat
```
**Note**: You'll need to enter the root password when prompted.

### 2. Automated Deployment
```bash
# Run the deployment script
C:\Users\hirotaka\Documents\work\deploy-to-server.bat
```

### 3. Manual Deployment (Alternative)
```bash
# Test SSH connection
ssh -i "auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200 "echo 'Connected!'"

# Copy Docker configuration
scp -i "auth_organized\keys_configs\mcp_docker_key" -r docker root@192.168.111.200:/root/
scp -i "auth_organized\keys_configs\mcp_docker_key" docker-compose.yml root@192.168.111.200:/var/deployment/

# Execute deployment script
ssh -i "auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200 "chmod +x /root/docker/scripts/deploy-docker.sh && /root/docker/scripts/deploy-docker.sh"
```

## 🌐 Service Access Points

After deployment, the following services will be available:

- **Main Website**: http://192.168.111.200
- **MCP API**: http://192.168.111.200:8080
- **React Application**: http://192.168.111.200:3000
- **Health Check**: http://192.168.111.200/health
- **Service Status**: http://192.168.111.200/service

## 🔍 Verification Commands

```bash
# Check container status via SSH
ssh -i "auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200 "docker ps"

# View container logs
ssh -i "auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200 "docker compose logs -f"

# Test endpoints
curl http://192.168.111.200
curl http://192.168.111.200:8080
curl http://192.168.111.200/health
```

## 🐳 Docker Container Management

### Start/Stop Services
```bash
# Start all containers
ssh -i mcp_docker_key root@192.168.111.200 "cd /var/deployment && docker compose up -d"

# Stop all containers
ssh -i mcp_docker_key root@192.168.111.200 "cd /var/deployment && docker compose down"

# Restart specific service
ssh -i mcp_docker_key root@192.168.111.200 "cd /var/deployment && docker compose restart mcp-server"
```

### Auto-Start Configuration
The deployment script automatically configures:
- ✅ Docker Compose to start on system boot
- ✅ Container restart policies (always)
- ✅ Health checks for all services
- ✅ systemd service for Docker Compose management

## 🔧 Troubleshooting

### SSH Connection Issues
1. Ensure SSH key is properly copied to server
2. Check key permissions: `chmod 600 mcp_docker_key`
3. Test manual password connection first

### Container Issues
1. Check logs: `docker compose logs [service_name]`
2. Verify images: `docker images`
3. Check network: `docker network inspect mcp-network`
4. Resource usage: `docker stats`

### Port Conflicts
- Ensure ports 80, 8080, 3000 are available
- Stop conflicting services: `systemctl stop nginx mcp-server`

## 📊 Monitoring

### Container Health
```bash
# Container status
docker compose ps

# Resource usage
docker stats --no-stream

# Network connectivity
docker exec mcp-server curl http://nginx-proxy
```

### Log Monitoring
```bash
# All container logs
docker compose logs -f

# Specific service logs
docker compose logs -f mcp-server
docker compose logs -f nginx-proxy
```

## 🚀 GitHub Actions (Future)
Once a GitHub repository is configured, the CI/CD pipeline will:
1. Automatically build Docker images
2. Run tests in containers
3. Deploy via SSH to the MCP server
4. Perform health checks
5. Send deployment notifications

The workflow is already configured in `.github/workflows/docker-cicd.yml`