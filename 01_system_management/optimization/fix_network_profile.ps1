# Fix Network Profile and Enable WinRM
# 調査PC (192.168.111.163) で管理者権限PowerShellで実行

Write-Host "=== NETWORK PROFILE FIX ===" -ForegroundColor Red
Write-Host "Fixing Public network issue for WinRM" -ForegroundColor Yellow

# 1. 現在のネットワークプロファイル確認
Write-Host "`n[1] Current network profiles:" -ForegroundColor Green
Get-NetConnectionProfile | Format-Table Name, NetworkCategory, InterfaceAlias

# 2. ネットワークプロファイルをPrivateに変更
Write-Host "`n[2] Changing network profile to Private..." -ForegroundColor Green
try {
    # すべてのネットワークをPrivateに変更
    Get-NetConnectionProfile | Where-Object {$_.NetworkCategory -eq "Public"} | ForEach-Object {
        Write-Host "Changing $($_.Name) from Public to Private..." -ForegroundColor Yellow
        Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private
    }
    Write-Host "✓ Network profiles updated to Private" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# 3. 変更後の確認
Write-Host "`n[3] Updated network profiles:" -ForegroundColor Green
Get-NetConnectionProfile | Format-Table Name, NetworkCategory, InterfaceAlias

# 4. WinRM設定を再実行
Write-Host "`n[4] Configuring WinRM with Private network..." -ForegroundColor Green
try {
    # WinRM有効化
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    
    # 設定変更
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/client '@{AllowUnencrypted="true"}'
    
    # 信頼ホスト設定
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    
    # ファイアウォール設定
    Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True -Profile Any
    Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -Enabled True -ErrorAction SilentlyContinue
    
    # サービス再起動
    Restart-Service WinRM
    
    Write-Host "✓ WinRM successfully configured!" -ForegroundColor Green
    
} catch {
    Write-Host "Error configuring WinRM: $_" -ForegroundColor Red
}

# 5. 接続テスト準備
Write-Host "`n[5] Ready for connection test" -ForegroundColor Green
Write-Host "WinRM service status:" -ForegroundColor Yellow
Get-Service WinRM | Format-Table Status, Name, DisplayName

Write-Host "`n[6] Test from remote machine (192.168.111.200):" -ForegroundColor Cyan
Write-Host @"
Test-NetConnection -ComputerName 192.168.111.163 -Port 5985
`$cred = Get-Credential -UserName "pc"
Enter-PSSession -ComputerName 192.168.111.163 -Credential `$cred
"@ -ForegroundColor White

Write-Host "`n=== CONFIGURATION COMPLETE ===" -ForegroundColor Green