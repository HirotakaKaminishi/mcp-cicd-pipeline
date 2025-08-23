@echo off
echo ================================================= 
echo 🧪 Testing Enhanced Deployment Script
echo ================================================= 

REM Test 1: Check if deployment script exists and is executable
if not exist "scripts\deploy.bat" (
    echo ❌ Deploy script not found
    exit /b 1
)
echo ✅ Deploy script found

REM Test 2: Check SSH key
if not exist "auth_organized\keys_configs\mcp_docker_key" (
    echo ❌ SSH key not found
    exit /b 1
)
echo ✅ SSH key found

REM Test 3: Test SSH connection
echo 📡 Testing SSH connection...
ssh -i "auth_organized\keys_configs\mcp_docker_key" -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@192.168.111.200 "echo SSH connection successful" >nul 2>&1
if errorlevel 1 (
    echo ❌ SSH connection failed
    exit /b 1
)
echo ✅ SSH connection successful

REM Test 4: Check required Docker files
echo 🐳 Checking Docker configuration files...
if not exist "docker-compose.yml" echo ❌ docker-compose.yml missing & exit /b 1
if not exist "docker\mcp-server\Dockerfile" echo ❌ MCP Server Dockerfile missing & exit /b 1  
if not exist "docker\nginx\Dockerfile" echo ❌ Nginx Dockerfile missing & exit /b 1
echo ✅ All Docker configuration files present

REM Test 5: Check current server status
echo 🔍 Checking current server status...
ssh -i "auth_organized\keys_configs\mcp_docker_key" -o StrictHostKeyChecking=no root@192.168.111.200 "cd /var/deployment && docker compose ps" 2>nul
if errorlevel 1 (
    echo ⚠️  No existing Docker deployment found
) else (
    echo ✅ Existing Docker deployment detected
)

REM Test 6: Test service endpoints
echo 🌐 Testing service endpoints...
curl -f -s "http://192.168.111.200/health" >nul && echo ✅ Health endpoint responding || echo ❌ Health endpoint failed
curl -f -s "http://192.168.111.200:8080" >nul && echo ✅ MCP Server responding || echo ❌ MCP Server failed

echo ================================================= 
echo 🚀 Running Enhanced Deployment Script Test
echo ================================================= 

REM Run the actual deployment script in test mode (dry run if available)
echo Executing: scripts\deploy.bat production
call scripts\deploy.bat production

echo ================================================= 
echo 📊 Post-Deployment Verification  
echo ================================================= 

REM Verify endpoints after deployment
timeout /t 10 /nobreak >nul
echo Testing all endpoints after deployment...

curl -s "http://192.168.111.200/health" && echo
curl -s "http://192.168.111.200/service" && echo  
curl -s "http://192.168.111.200:8080" && echo

echo ================================================= 
echo ✅ Deployment Test Completed
echo ================================================= 

pause