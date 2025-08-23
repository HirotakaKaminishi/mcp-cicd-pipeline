@echo off
REM TrustedHosts設定バッチファイル
REM 右クリック → 「管理者として実行」

echo === Setting TrustedHosts for Remote Investigation ===
echo.

REM 管理者権限確認
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Administrator privileges required!
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Running with Administrator privileges...
echo.

REM TrustedHostsに対象PCを追加
echo Adding 192.168.111.163 to TrustedHosts...
powershell -Command "Set-Item WSMan:\localhost\Client\TrustedHosts -Value '192.168.111.163' -Force"

REM 確認
echo.
echo Current TrustedHosts:
powershell -Command "Get-Item WSMan:\localhost\Client\TrustedHosts"

echo.
echo === Setup Complete ===
echo You can now connect to 192.168.111.163 using PSRemoting
echo.
echo Next step: Run remote_investigation_with_creds.ps1
pause