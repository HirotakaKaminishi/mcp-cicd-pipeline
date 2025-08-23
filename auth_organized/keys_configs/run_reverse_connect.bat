@echo off
REM 対象PC用の簡易実行バッチファイル
REM 管理者権限で実行してください

echo === Reverse SSH Connection to Investigation Server ===
echo Target: 192.168.111.55:2222
echo.

REM PowerShellスクリプトの実行
powershell -ExecutionPolicy Bypass -File "%~dp0simple_reverse_connect.ps1"

pause