@echo off
REM Legacy deployment script - Use the new enhanced script instead
echo ===================================
echo Enhanced Docker Deployment Script
echo ===================================
echo.
echo This script has been replaced with a more robust version.
echo Please use one of the following:
echo.
echo For Windows:
echo   scripts\deploy.bat
echo.
echo For Linux/macOS:
echo   ./scripts/deploy.sh
echo.
echo These new scripts include:
echo ✅ Comprehensive error checking
echo ✅ Service health verification  
echo ✅ Auto-start configuration
echo ✅ Detailed status reporting
echo.
echo Running the new Windows deployment script...
echo ===================================

REM Call the new enhanced script
call scripts\deploy.bat %*