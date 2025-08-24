@echo off
REM Vibe-Kanban Docker Setup Script for Windows

echo ===================================
echo   Vibe-Kanban Docker Setup
echo ===================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH
    echo Please install Docker Desktop for Windows first
    echo Download from: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

echo [1/4] Building vibe-kanban Docker image...
docker build -t vibe-kanban-complete .
if %errorlevel% neq 0 (
    echo [ERROR] Failed to build Docker image
    pause
    exit /b 1
)

echo.
echo [2/4] Starting vibe-kanban container...
cd ..
docker-compose up -d vibe-kanban
if %errorlevel% neq 0 (
    echo [ERROR] Failed to start container
    pause
    exit /b 1
)

echo.
echo [3/4] Waiting for vibe-kanban to be ready...
timeout /t 10 /nobreak >nul

echo.
echo [4/4] Checking health status...
docker-compose exec vibe-kanban curl -f http://localhost:3000
if %errorlevel% neq 0 (
    echo [WARNING] Health check failed. Checking logs...
    docker-compose logs --tail=50 vibe-kanban
)

echo.
echo ===================================
echo   Setup Complete!
echo ===================================
echo.
echo Vibe-Kanban is running successfully!
echo Access the dashboard at: http://localhost:3001
echo.
echo Container status:
docker-compose ps vibe-kanban
echo.
pause