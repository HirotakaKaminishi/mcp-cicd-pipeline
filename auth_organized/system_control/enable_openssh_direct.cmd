@echo off
REM Direct OpenSSH Server Installation via DISM
REM Run as Administrator

echo === Direct OpenSSH Server Installation ===
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Must run as Administrator
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Running as Administrator...
echo.

REM Method 1: DISM command
echo 1. Installing OpenSSH Server using DISM...
dism /online /add-capability /capabilityname:OpenSSH.Server~~~~0.0.1.0

REM Method 2: PowerShell Add-WindowsCapability
echo.
echo 2. Installing OpenSSH Server using PowerShell...
powershell -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"

REM Check installation
echo.
echo 3. Checking installation...
dir "C:\Windows\System32\OpenSSH\sshd.exe" 2>nul && echo SUCCESS: sshd.exe found || echo WARNING: sshd.exe not found

REM Create and start service
echo.
echo 4. Starting SSH service...
sc create sshd binPath="C:\Windows\System32\OpenSSH\sshd.exe" DisplayName="OpenSSH SSH Server" start=auto
sc start sshd

REM Check service status
echo.
echo 5. Service status:
sc query sshd

REM Configure firewall
echo.
echo 6. Configuring firewall...
netsh advfirewall firewall add rule name="OpenSSH Server" dir=in action=allow protocol=TCP localport=22
netsh advfirewall firewall add rule name="SSH Investigation Port" dir=in action=allow protocol=TCP localport=2222

echo.
echo === Installation Complete ===
echo.

REM Test connection
echo 7. Testing connection...
powershell -Command "Test-NetConnection -ComputerName 127.0.0.1 -Port 22"

echo.
echo If SSH is working, target PC can connect with:
echo ssh -R 3333:localhost:22 hirotaka@192.168.111.55
echo.
pause