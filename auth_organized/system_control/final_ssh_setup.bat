@echo off
REM Final SSH Server Setup - Run as Administrator
echo === Final SSH Server Setup ===
echo Please run this as Administrator

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges
    echo Please right-click and "Run as administrator"
    pause
    exit /b 1
)

echo Running with Administrator privileges...

REM Install OpenSSH Server
echo.
echo 1. Installing OpenSSH Server...
powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"

REM Start and configure SSH service
echo.
echo 2. Starting SSH service...
powershell -Command "Start-Service sshd"
powershell -Command "Set-Service -Name sshd -StartupType 'Automatic'"

REM Configure SSH Agent
echo.
echo 3. Configuring SSH Agent...
powershell -Command "Start-Service ssh-agent"
powershell -Command "Set-Service -Name ssh-agent -StartupType 'Automatic'"

REM Configure Firewall
echo.
echo 4. Configuring firewall...
powershell -Command "New-NetFirewallRule -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue"
powershell -Command "New-NetFirewallRule -DisplayName 'SSH Investigation Port' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2222 -ErrorAction SilentlyContinue"

REM Wait and test
echo.
echo 5. Testing connection...
timeout /t 3 /nobreak
powershell -Command "Test-NetConnection -ComputerName 127.0.0.1 -Port 22"

echo.
echo === Setup Complete ===
echo SSH Server should now be running on port 22
echo Target PC can connect using: ssh -R 3333:localhost:22 hirotaka@192.168.111.55
pause