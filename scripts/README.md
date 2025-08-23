# 🚀 Deployment Scripts

This directory contains scripts for deploying the MCP Server Docker environment.

## 📋 Available Scripts

### Manual Deployment

#### Windows
```cmd
scripts\deploy.bat [environment]
```

#### Linux/macOS
```bash
./scripts/deploy.sh [environment]
```

**Environment options:**
- `dev` - Development environment
- `staging` - Staging environment  
- `production` - Production environment (default)

### Features

✅ **Comprehensive Checks**
- SSH connectivity verification
- Required file validation
- Pre-deployment environment checks

✅ **Robust Deployment**
- Automatic service stopping
- Docker image building with caching
- Container health monitoring
- Service endpoint verification

✅ **Auto-Start Configuration**
- systemd service setup for boot startup
- Container restart policies
- Service dependency management

✅ **Status Reporting**
- Real-time deployment progress
- Service health verification
- Detailed error reporting

## 🔧 Prerequisites

### SSH Key Setup
1. Run the SSH key setup (first time only):
   ```cmd
   # Windows
   auth_organized\keys_configs\setup_ssh_docker.bat
   
   # Or manually copy key
   ssh-copy-id -i auth_organized/keys_configs/mcp_docker_key.pub root@192.168.111.200
   ```

### Required Files
- `docker-compose.yml` - Docker Compose configuration
- `docker/` - Docker build configurations
- `03_sample_projects/react_apps/` - React application source

## 🤖 GitHub Actions Automation

### Workflow File
The GitHub Actions workflow is located at:
```
.github/workflows/docker-deploy.yml
```

### Required Secrets
Configure these secrets in your GitHub repository:

1. **SSH Private Key**
   ```
   Name: MCP_DOCKER_SSH_KEY
   Value: [Content of auth_organized/keys_configs/mcp_docker_key]
   ```

### Workflow Triggers
- **Push to main branch** - Automatic deployment to production
- **Push to develop branch** - Run tests only
- **Pull requests to main** - Run tests and validation

### Workflow Steps
1. **Test Phase**
   - Install React dependencies
   - Run React tests
   - Validate Docker builds
   - Code linting

2. **Deploy Phase** (main branch only)
   - Copy files to server via SSH
   - Build Docker images on server
   - Deploy containers with docker-compose
   - Configure auto-start service
   - Verify deployment health

3. **Notification Phase**
   - Report deployment status
   - Log results to server

## 📊 Service Monitoring

After deployment, services are available at:

- **🌐 Main Website**: http://192.168.111.200
- **❤️ Health Check**: http://192.168.111.200/health  
- **🔧 Service Status**: http://192.168.111.200/service
- **🚀 MCP API**: http://192.168.111.200:8080

### Health Check Commands

```bash
# Test all endpoints
curl http://192.168.111.200/health
curl http://192.168.111.200/service  
curl http://192.168.111.200:8080

# Check container status
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose ps"

# View container logs
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose logs -f"
```

## 🛠 Troubleshooting

### Common Issues

#### SSH Connection Failed
```bash
# Test SSH connectivity
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 "echo 'OK'"

# Fix permissions
chmod 600 auth_organized/keys_configs/mcp_docker_key
```

#### Docker Build Failed
```bash
# Check Docker status on server
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "docker --version && docker compose --version"

# Clear Docker cache
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "docker system prune -af"
```

#### Service Not Responding
```bash
# Check container logs
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose logs [service-name]"

# Restart specific service  
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose restart [service-name]"
```

### Manual Recovery

If deployment fails, you can manually recover:

```bash
# SSH into server
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200

# Navigate to deployment directory
cd /var/deployment

# Check status
docker compose ps
docker compose logs

# Restart services
docker compose down
docker compose up -d

# Check health
curl localhost/health
curl localhost:8080
```

## 📝 Configuration

### Environment Variables
You can customize deployment by setting environment variables:

```bash
# Custom server host
export MCP_SERVER_HOST="your-server-ip"

# Custom deployment path
export DEPLOY_PATH="/your/custom/path"

# Custom SSH key
export SSH_KEY="path/to/your/key"
```

### Docker Compose Override
For environment-specific configurations, create:
- `docker-compose.dev.yml`
- `docker-compose.staging.yml`  
- `docker-compose.prod.yml`

Use with:
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```