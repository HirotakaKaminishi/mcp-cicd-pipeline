# Fully Containerized MCP Server CI/CD Pipeline

Complete Docker-based implementation of CI/CD pipeline with multi-container architecture and automated GitHub Actions deployment.

## 🏗️ Container Architecture Overview

```
GitHub Repository → GitHub Actions → Docker Build → Docker Compose Deployment
                                          ↓
    ┌─────────────────── Container Orchestration ───────────────────┐
    │                                                               │
    │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
    │  │   Nginx      │  │  MCP Server  │  │   React App      │   │
    │  │   Proxy      │  │  Extended    │  │   (Vite/React)   │   │
    │  │   :80        │  │  :8080       │  │   :3000          │   │
    │  └──────────────┘  └──────────────┘  └──────────────────┘   │
    │           │                │                    │           │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │            Docker Network (mcp-network)              │   │
    │  │                172.20.0.0/16                        │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                               │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │         Deployment Manager Container             │   │
    │  │              (CI/CD Automation)                      │   │
    │  └──────────────────────────────────────────────────────┘   │
    └───────────────────────────────────────────────────────────────┘
```

## 📁 Docker Configuration Files

### 1. Container Orchestration
- **`docker-compose.yml`** - **Main Docker Compose Configuration**
  - Multi-service container orchestration
  - Network and volume management
  - Auto-restart and health check configuration

### 2. Container Definitions (mcp-cicd-pipeline/docker-enhanced/)
- **`mcp-server/`** - **MCP Server Extended Container**
  - `Dockerfile` - Python-based MCP server with build dependencies
  - `mcp_server_extended.py` - Enhanced MCP server with container support
- **`nginx/`** - **Nginx Reverse Proxy Container**
  - `Dockerfile` - Alpine-based Nginx
  - `nginx.conf` - Optimized Nginx configuration
  - `default.conf` - Proxy and routing rules
- **`react-app/`** - **React Application Container**
  - `Dockerfile` - Node.js 20 with Vite support
- **`deployment/`** - **Deployment Manager Container**
  - `Dockerfile` - CI/CD automation container
  - `package.json` - Deployment tool dependencies

### 3. GitHub Actions Docker Workflow
- **`.github/workflows/docker-deploy.yml`** - **Enhanced Docker-based CI/CD Pipeline**
  - Multi-stage Docker builds with comprehensive testing
  - SSH-based container deployment and orchestration
  - Automated health verification and monitoring
  - systemd auto-start service configuration
  - Full deployment rollback capabilities

### 4. Deployment Scripts
- **`scripts/`** - **Enhanced Deployment Scripts**
  - `deploy.sh` - Linux/macOS deployment script with comprehensive checks
  - `deploy.bat` - Windows deployment script with error handling
  - `README.md` - Detailed deployment script documentation

### 5. Application Source
- **`03_sample_projects/react_apps/`** - **React Application Source**
  - Modern React with Vite build system
  - Container-optimized development workflow
  - Integrated testing and linting

### 6. Setup Guides
- **`GITHUB_ACTIONS_SETUP.md`** - **Complete GitHub Actions Configuration Guide**
  - GitHub repository setup
  - Secrets configuration
  - Workflow troubleshooting
  - CI/CD best practices

## 🔑 SSH Access Configuration

### Initial SSH Key Setup
```bash
# Generate SSH key (already done)
ssh-keygen -t rsa -b 4096 -f mcp_docker_key -C "mcp-docker-deployment"

# Copy key to server (first time only - requires password)
ssh-copy-id -i mcp_docker_key.pub root@192.168.111.200

# Or use the setup script
C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\setup_ssh_docker.bat
```

### SSH Connection Methods
```bash
# Direct SSH connection
ssh -i "C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200

# Execute remote commands
ssh -i mcp_docker_key root@192.168.111.200 "docker ps"
ssh -i mcp_docker_key root@192.168.111.200 "docker compose logs -f"
```

## 🚀 Deployment Options

### 1. Enhanced Deployment Scripts (Recommended)

#### Windows Deployment
```cmd
# Enhanced deployment with full error checking
scripts\deploy.bat

# Deploy to specific environment
scripts\deploy.bat production
scripts\deploy.bat staging
```

#### Linux/macOS Deployment
```bash
# Make script executable (first time only)
chmod +x scripts/deploy.sh

# Deploy with comprehensive checks
./scripts/deploy.sh

# Deploy to specific environment
./scripts/deploy.sh production
./scripts/deploy.sh staging
```

#### Script Features
✅ SSH connectivity verification  
✅ Pre-deployment validation checks  
✅ Automatic service conflict resolution  
✅ Real-time deployment progress  
✅ Health endpoint verification  
✅ systemd auto-start configuration  
✅ Detailed error reporting  

### 2. Manual Local Development
```bash
# Navigate to project directory
cd C:\Users\hirotaka\Documents\work

# Start all containers
docker-compose up -d

# Check container status
docker-compose ps

# View logs
docker-compose logs -f
```

### 2. Container Management
```bash
# Stop all containers
docker-compose down

# Rebuild and restart
docker-compose up -d --build

# Scale specific service
docker-compose up -d --scale react-app=2

# Access container shell
docker-compose exec mcp-server /bin/sh
docker-compose exec nginx-proxy /bin/sh
```

### 3. Development Workflow
```bash
# Run tests in container
docker-compose exec react-app npm test

# Run build in container
docker-compose exec react-app npm run build

# Check MCP server health
curl http://192.168.111.200:8080

# Access application
curl http://192.168.111.200
```

### 4. GitHub Actions Automated CI/CD

#### Setup (First Time Only)
1. **Configure Secrets**: See `GITHUB_ACTIONS_SETUP.md` for detailed instructions
   ```
   Repository Settings → Secrets → Actions
   Add: MCP_DOCKER_SSH_KEY (SSH private key content)
   ```

2. **Push to Repository**
   ```bash
   git add .
   git commit -m "feat: enhanced Docker CI/CD with automated deployment"
   git push origin main
   ```

#### Deployment Triggers
```bash
# Production deployment (automatic)
git push origin main

# Development testing only
git push origin develop

# Manual deployment trigger
# GitHub → Actions → "Docker MCP Server CI/CD Pipeline" → Run workflow
```

#### Workflow Features
✅ **Test Phase**: React tests, Docker builds, linting  
✅ **Deploy Phase**: SSH deployment, container orchestration  
✅ **Verification**: Health checks, service validation  
✅ **Auto-start**: systemd service configuration  
✅ **Monitoring**: Real-time deployment status  

#### Workflow File
- **Location**: `.github/workflows/docker-deploy.yml`
- **Documentation**: See `GITHUB_ACTIONS_SETUP.md`
- **Troubleshooting**: Detailed guides in setup documentation

## 🔧 Docker Pipeline Details

### Container-based Workflow Stages
1. **Test** - Containerized testing (Jest, ESLint, React tests)
2. **Build** - Multi-stage Docker image builds
3. **Deploy** - Docker Compose orchestrated deployment
4. **Health Check** - Container health verification
5. **Notify** - Multi-container deployment status

### Enhanced MCP API Features (Containerized)
- `execute_command` - Container command execution
- `read_file` - Container filesystem access
- `write_file` - Container configuration management
- `list_directory` - Container directory listing
- `manage_service` - Docker service management
- `get_system_info` - Container system monitoring
- `deploy_application` - **New: Container-based app deployment**
- `health_check` - **New: Multi-container health monitoring**

### Container-aware MCP Commands (Claude Code Integration)
```bash
# Container operations via MCP Server Extended
/remote-extended:get_system_info
/remote-extended:execute_command "docker ps"
/remote-extended:execute_command "docker-compose logs mcp-server"
/remote-extended:health_check
/remote-extended:deploy_application "my-app" "/var/deployment/apps/"
```

## 📊 Docker System Requirements

### Remote Server (Docker Host)
- **Linux**: Rocky Linux 9 or compatible
- **Docker**: 20.10+ with Docker Compose
- **Python**: 3.9+ (for MCP server container)
- **Node.js**: 18+ (for React app container)
- **Available Ports**: 80, 8080, 3000 (container-mapped)
- **Memory**: 4GB+ recommended for multi-container deployment

### Local Development
- **Docker Desktop**: Latest version
- **Git**: Version control
- **Node.js**: 18+ for local development

### GitHub Actions
- **ubuntu-latest runner** with Docker support
- **Docker BuildX** for multi-platform builds
- **Container registry access** (optional)

## 🔒 Container Security

- **Isolated containers**: Each service runs in its own container
- **Non-root users**: Containers run with restricted privileges
- **Network segmentation**: Custom Docker network with controlled access
- **Health checks**: Automated container health monitoring
- **GitHub Secrets**: Secure environment variable management
- **Container image scanning**: Security vulnerability checks

## 🏃‍♂️ Container Operation Test Results

- ✅ **Docker Multi-container deployment**
- ✅ **MCP API container-to-container communication**
- ✅ **Nginx reverse proxy functionality**
- ✅ **React application containerized serving**
- ✅ **Container auto-restart and health checks**
- ✅ **GitHub Actions Docker-based CI/CD**
- ✅ **Container log aggregation and monitoring**

## 🛠️ Container Customization

### Docker Compose Configuration
```yaml
# Modify docker-compose.yml
services:
  mcp-server:
    environment:
      - MCP_SERVER_PORT=8080
      - CUSTOM_CONFIG=value
    volumes:
      - ./custom-config:/app/config
```

### Container Environment Variables
```yaml
# In .github/workflows/docker-cicd.yml
env:
  MCP_SERVER_URL: http://192.168.111.200:8080
  DOCKER_COMPOSE_VERSION: 2.21.0
  CUSTOM_SETTING: value
```

### Scaling Containers
```bash
# Scale React app containers
docker-compose up -d --scale react-app=3

# Custom container resource limits
docker-compose exec mcp-server sh -c "cat /proc/meminfo"
```

## 📈 Container Monitoring

- **Container Logs**: `docker-compose logs -f [service]`
- **MCP Container Log**: `/var/log/mcp/mcp_server.log` (inside container)
- **Nginx Container Log**: `/var/log/nginx/access.log` (inside container)
- **Health Status**: `docker-compose ps`
- **Resource Usage**: `docker stats`

## 🔧 Container Troubleshooting

### Common Container Issues
1. **Container Won't Start** → Check `docker-compose logs [service]`
2. **Port Conflicts** → Verify port mappings in `docker-compose.yml`
3. **Container Communication** → Check Docker network: `docker network inspect mcp-network`
4. **Health Check Failures** → Container health: `docker-compose ps`
5. **Resource Issues** → Monitor: `docker system df` and `docker stats`

### Container Debugging Commands
```bash
# Enter running container
docker-compose exec mcp-server /bin/sh

# Check container network
docker network ls
docker network inspect mcp-network

# View container resource usage
docker stats --no-stream

# Container filesystem check
docker-compose exec mcp-server df -h
```

---

**🐳 A fully containerized, auto-scaling CI/CD pipeline is now operational!**

**Key Benefits:**
- ✅ **Complete isolation** - No host OS conflicts
- ✅ **Easy scaling** - Container replication
- ✅ **Consistent environments** - Dev/prod parity
- ✅ **Auto-recovery** - Container restart policies
- ✅ **Resource efficiency** - Optimized container images