# Claude Code Project Configuration

## 📋 Essential Tasks on Claude Code Startup
**⚠️ Important**: When starting Claude Code, please execute the following steps:

1. **Auto-reference CLAUDE.md**: Load CLAUDE.md immediately after startup to understand project settings
2. **MCP Server Connection Check**: Verify MCP server connection status with `/mcp` command  
3. **Work Environment Recognition**: Recognize default working directory `C:\Users\hirotaka\Documents\work\`

### Claude Code Startup Command
```bash
claude --settings ".claude/settings.local.json" --dangerously-skip-permissions --continue
```

## Working Directory Settings
- **Default Working Directory**: `C:\Users\hirotaka\Documents\work\`
- When "working directory" is mentioned, automatically recognize this path

## Project Overview
- **Fully Containerized MCP Server CI/CD Pipeline**
- **Docker Compose Multi-Service Architecture**
- **GitHub Actions Docker-based Deployment**
- **Automated Container Management**

## Important Files
- `README.md` - Project Documentation
- `docker-compose.yml` - **Main Docker Compose Configuration**
- `docker/` - **Docker Container Definitions**
  - `docker/mcp-server/` - MCP Server Container
  - `docker/nginx/` - Nginx Proxy Container
  - `docker/react-app/` - React Application Container
  - `docker/deployment/` - Deployment Manager Container
- `.github/workflows/docker-cicd.yml` - **Docker-based GitHub Actions Workflow**
- `03_sample_projects/react_apps/` - React Application Source

## Docker Development Commands
- **Full Stack Start**: `docker-compose up -d`
- **Full Stack Stop**: `docker-compose down`
- **Rebuild Containers**: `docker-compose up -d --build`
- **View Container Logs**: `docker-compose logs -f [service_name]`
- **Container Status**: `docker-compose ps`
- **Test Execution**: `docker-compose exec react-app npm test`
- **Build Production**: `docker-compose exec react-app npm run build`

## AI Assistant Tasks
- **Container Log Monitoring**: `docker-compose logs`
- **MCP Server Container Log**: `docker exec mcp-server tail -f /var/log/mcp/mcp_server.log`
- **Nginx Container Log**: `docker exec nginx-proxy tail -f /var/log/nginx/access.log`
- **Application Log**: Docker container logs
- **Error Diagnosis Areas**:
  - Docker Container Error → Container status・Log check
  - MCP Connection Error → Container network・Port binding
  - Deploy Failure → GitHub Actions logs・Container build logs
  - Service Startup Error → Docker Compose configuration

## Containerized MCP API Functions
- `execute_command` - Remote Command Execution (in containers)
- `read_file` - File Reading (container filesystem)
- `write_file` - Configuration File Management
- `list_directory` - Directory Listing
- `manage_service` - Docker Service Control
- `get_system_info` - Container System Monitoring
- `deploy_application` - **New: Container-based deployment**
- `health_check` - **New: Multi-container health monitoring**

## 🔑 SSH Alternative Connection Method
**When MCP Server is not accessible**, use SSH as a fallback:

### SSH Key Setup (First Time Only)
```bash
# Run the setup script to copy SSH key to server
C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\setup_ssh_docker.bat
# Enter root password when prompted
```

### SSH Connection Commands
```bash
# Connect using SSH key
ssh -i "C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200

# Direct command execution
ssh -i "C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200 "docker ps"

# Start MCP server temporarily
ssh -i "C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200 "systemctl start mcp-server"

# Deploy Docker containers
ssh -i "C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\mcp_docker_key" root@192.168.111.200 "cd /var/deployment && docker compose up -d"
```

### Available SSH Keys
- **Primary**: `mcp_docker_key` - Docker deployment key (RSA 4096-bit)
- **Location**: `C:\Users\hirotaka\Documents\work\auth_organized\keys_configs\`

## MCP Tool Command Usage
**⚠️ Important**: MCP Server is now running as a Docker container. Use these commands:

```bash
# Container-based System Information
/remote-extended:get_system_info

# Container Command Execution  
/remote-extended:execute_command "docker exec mcp-server [command]"

# Container File Reading
/remote-extended:read_file "/var/deployment/path/to/file"

# Container File Writing
/remote-extended:write_file "/var/deployment/path/to/file" "content"

# Container Directory Listing
/remote-extended:list_directory "/var/deployment"

# Docker Service Management
/remote-extended:execute_command "docker-compose restart [service]"

# Container Health Check
/remote-extended:health_check

# Application Deployment
/remote-extended:deploy_application "app_name" "/source/path"
```

### MCP Tool Command Auto-completion
- After starting Claude Code, typing `/` will display MCP command auto-completion
- Tab key enables command completion

## Docker Environment Settings
- **MCP Server Container**: `mcp-server:8080` (internal), `192.168.111.200:8080` (external)
- **Nginx Proxy Container**: `nginx-proxy:80` (internal), `192.168.111.200:80` (external)
- **React App Container**: `react-app:3000` (internal), accessible via Nginx proxy
- **Container Network**: `mcp-network` (172.20.0.0/16)
- **Remote Server**: Linux localhost.localdomain (Docker Host)

## Docker-based React Application Development Procedure (Mandatory Compliance)

### 1. Docker Development Environment Setup
```bash
# Navigate to project root
cd C:\Users\hirotaka\Documents\work

# Start all services with Docker Compose
docker-compose up -d

# Check all containers are running
docker-compose ps

# Access development environment
# Main Site: http://192.168.111.200
# React App: http://192.168.111.200/app/
# MCP API: http://192.168.111.200/api/mcp/
```

### 2. Development Workflow
```bash
# Make changes to React application
cd 03_sample_projects/react_apps
# Edit files...

# Rebuild React container with changes
docker-compose build react-app
docker-compose up -d react-app

# Run tests in container
docker-compose exec react-app npm test

# Run linting in container
docker-compose exec react-app npm run lint
```

### 3. Operation Confirmation of Changes
- **Required**: Confirm all changes in Docker environment
- **Container Access**: All services running in isolated containers
- **Routing**: `/`, `/health`, `/service`, `/app/` should work correctly
- **API Endpoint**: Requests to `/api/mcp/` should be processed normally
- **MCP Server Integration**: Container-to-container communication verified

### 4. Build and Test (Containerized)
```bash
# Production build in container
docker-compose exec react-app npm run build

# Build result confirmation
docker-compose exec react-app ls dist/

# Full stack testing
docker-compose exec nginx-proxy curl -f http://localhost/
docker-compose exec nginx-proxy curl -f http://localhost/health
docker-compose exec nginx-proxy curl -f http://localhost/service
```

### 5. Git Commit and Push (Docker-optimized)
```bash
# Check changed files
git status

# Stage changes
git add .

# Commit with Docker context
git commit -m "feat: Docker containerization - migrate to multi-container architecture"

# Push to GitHub (triggers Docker-based deployment)
git push origin main
```

### 6. Docker-based Deployment from GitHub Actions
- **GitHub Actions**: Automatically triggered with Docker workflow
- **Workflow**: `.github/workflows/docker-cicd.yml`
- **Build Process**: Multi-stage Docker builds
- **Deployment**: Container orchestration with Docker Compose
- **Health Checks**: Automated container health verification

### 7. Production Environment Operation Check (Containerized)
```bash
# Check all containers are running
curl -X POST http://192.168.111.200:8080 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"execute_command","params":{"command":"docker ps"},"id":1}'

# Test all endpoints
curl http://192.168.111.200/
curl http://192.168.111.200/health  
curl http://192.168.111.200/service
curl http://192.168.111.200/app/
curl http://192.168.111.200/api/mcp/
```

## Important Notes (Docker Environment)
- **All services run in isolated containers**
- **No direct host OS editing - everything containerized**
- **Use Docker Compose for local development**
- **Container-to-container communication via Docker network**
- **Persistent data stored in Docker volumes**
- **Auto-restart enabled for all containers**
- **Health checks monitor all services**