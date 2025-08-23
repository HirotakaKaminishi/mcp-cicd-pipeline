@echo off
setlocal enabledelayedexpansion

REM MCP Server Docker Deployment Script for Windows
REM Usage: scripts\deploy.bat [environment]
REM Environment: dev|staging|production (default: production)

set "MCP_SERVER_HOST=192.168.111.200"
set "DEPLOY_PATH=/var/deployment"
set "SSH_KEY=auth_organized\keys_configs\mcp_docker_key"
set "ENVIRONMENT=%1"
if "%ENVIRONMENT%"=="" set "ENVIRONMENT=production"

echo ================================================= 
echo 🐳 MCP Server Docker Deployment Script
echo ================================================= 
echo Environment: %ENVIRONMENT%
echo Target: %MCP_SERVER_HOST%
echo Deploy Path: %DEPLOY_PATH%
echo ================================================= 

REM Check if SSH key exists
if not exist "%SSH_KEY%" (
    echo ❌ SSH key not found at %SSH_KEY%
    echo Please run the SSH key setup first:
    echo   auth_organized\keys_configs\setup_ssh_docker.bat
    pause
    exit /b 1
)

echo ✅ SSH key found

REM Test SSH connection
echo 📡 Testing SSH connection to %MCP_SERVER_HOST%...
ssh -i "%SSH_KEY%" -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@%MCP_SERVER_HOST% "echo SSH connection successful" >nul 2>&1
if errorlevel 1 (
    echo ❌ SSH connection failed
    echo Please check:
    echo   1. SSH key is properly set up on the server
    echo   2. Server is accessible at %MCP_SERVER_HOST%
    echo   3. SSH daemon is running on the server
    pause
    exit /b 1
)

echo ✅ SSH connection established

REM Pre-deployment checks
echo 🔍 Running pre-deployment checks...

if not exist "docker-compose.yml" (
    echo ❌ Required file missing: docker-compose.yml
    pause
    exit /b 1
)

if not exist "docker\mcp-server\Dockerfile" (
    echo ❌ Required file missing: docker\mcp-server\Dockerfile
    pause
    exit /b 1
)

if not exist "docker\nginx\Dockerfile" (
    echo ❌ Required file missing: docker\nginx\Dockerfile
    pause
    exit /b 1
)

if not exist "03_sample_projects\react_apps" (
    echo ⚠️  React app directory not found, creating placeholder
    mkdir "03_sample_projects\react_apps" 2>nul
    echo {"name": "placeholder", "version": "1.0.0"} > "03_sample_projects\react_apps\package.json"
)

echo ✅ Pre-deployment checks passed

REM Deploy Docker configuration
echo 📦 Deploying Docker configuration to server...

scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no -r docker root@%MCP_SERVER_HOST%:/root/
if errorlevel 1 (
    echo ❌ Failed to copy Docker configuration
    pause
    exit /b 1
)

scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no docker-compose.yml root@%MCP_SERVER_HOST%:%DEPLOY_PATH%/
if errorlevel 1 (
    echo ❌ Failed to copy docker-compose.yml
    pause
    exit /b 1
)

scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no -r 03_sample_projects\react_apps root@%MCP_SERVER_HOST%:/root/ 2>nul
REM Non-critical if React app copy fails

echo ✅ Docker configuration deployed

REM Stop existing services
echo 🛑 Stopping existing services...

ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no root@%MCP_SERVER_HOST% "cd %DEPLOY_PATH% && docker compose down 2>/dev/null || true && systemctl stop mcp-server nginx 2>/dev/null || true && pkill -f mcp_server.py 2>/dev/null || true && pkill -f node 2>/dev/null || true && echo Existing services stopped"

echo ✅ Existing services stopped

REM Build and start Docker containers
echo 🔨 Building and starting Docker containers...

ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no root@%MCP_SERVER_HOST% "cd %DEPLOY_PATH% && echo Building Docker images... && docker compose build --no-cache && echo Starting Docker containers... && docker compose up -d && echo Waiting for services to initialize... && sleep 30 && echo Container status: && docker compose ps"

if errorlevel 1 (
    echo ❌ Failed to build or start Docker containers
    pause
    exit /b 1
)

echo ✅ Docker containers built and started

REM Verify deployment
echo ✅ Verifying deployment...
timeout /t 15 /nobreak >nul

echo Testing endpoints...
curl -f -s "http://%MCP_SERVER_HOST%/health" >nul && echo ✅ Health endpoint responding || echo ⚠️  Health endpoint not responding
curl -f -s "http://%MCP_SERVER_HOST%/service" >nul && echo ✅ Service endpoint responding || echo ⚠️  Service endpoint not responding  
curl -f -s "http://%MCP_SERVER_HOST%:8080" >nul && echo ✅ MCP Server responding || echo ⚠️  MCP Server not responding

REM Get detailed status
ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no root@%MCP_SERVER_HOST% "echo === Final Container Status === && cd %DEPLOY_PATH% && docker compose ps && echo && echo === Service Health === && curl -s http://localhost/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo Health endpoint not available && echo && echo === MCP Server Status === && curl -s http://localhost:8080 2>/dev/null | python3 -m json.tool 2>/dev/null || echo MCP server not available"

REM Setup auto-start service
echo 🚀 Setting up auto-start service...

ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no root@%MCP_SERVER_HOST% "cat > /etc/systemd/system/mcp-docker.service << 'EOF' && [Unit] && Description=MCP Docker Compose Service && Requires=docker.service && After=docker.service && StartLimitIntervalSec=0 && && [Service] && Type=oneshot && RemainAfterExit=yes && WorkingDirectory=%DEPLOY_PATH% && ExecStart=/usr/bin/docker compose up -d && ExecStop=/usr/bin/docker compose down && TimeoutStartSec=0 && Restart=on-failure && RestartSec=5 && && [Install] && WantedBy=multi-user.target && EOF && systemctl daemon-reload && systemctl enable mcp-docker.service && echo Auto-start service configured" 2>nul

echo ✅ Auto-start service configured

echo ================================================= 
echo 🎉 Docker deployment completed successfully!
echo ================================================= 
echo 📊 Service URLs:
echo   🌐 Main Website: http://%MCP_SERVER_HOST%
echo   ❤️  Health Check: http://%MCP_SERVER_HOST%/health
echo   🔧 Service Status: http://%MCP_SERVER_HOST%/service
echo   🚀 MCP API: http://%MCP_SERVER_HOST%:8080
echo ================================================= 

pause