# WinRM完全セットアップスクリプト
# 管理者権限で実行してください

Write-Host "=== Complete WinRM Setup ===" -ForegroundColor Green

# 管理者権限確認
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Administrator privileges required!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    # 1. WinRMサービスの起動
    Write-Host "`n1. Starting WinRM service..." -ForegroundColor Yellow
    Start-Service WinRM -ErrorAction Stop
    Set-Service -Name WinRM -StartupType Automatic
    $winrmStatus = Get-Service WinRM
    Write-Host "✅ WinRM Status: $($winrmStatus.Status)" -ForegroundColor Green
    
    # 2. WinRM基本設定
    Write-Host "`n2. Configuring WinRM..." -ForegroundColor Yellow
    winrm quickconfig -q
    Write-Host "✅ WinRM configured" -ForegroundColor Green
    
    # 3. ネットワークプロファイル確認（必要に応じてPrivateに変更）
    Write-Host "`n3. Checking network profile..." -ForegroundColor Yellow
    $networkProfile = Get-NetConnectionProfile
    if ($networkProfile.NetworkCategory -eq "Public") {
        Write-Host "Changing network profile from Public to Private..." -ForegroundColor Yellow
        Set-NetConnectionProfile -NetworkCategory Private
        Write-Host "✅ Network profile changed to Private" -ForegroundColor Green
    } else {
        Write-Host "✅ Network profile is already $($networkProfile.NetworkCategory)" -ForegroundColor Green
    }
    
    # 4. TrustedHostsの設定
    Write-Host "`n4. Setting TrustedHosts..." -ForegroundColor Yellow
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.111.163" -Force
    $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts
    Write-Host "✅ TrustedHosts: $($trustedHosts.Value)" -ForegroundColor Green
    
    # 5. ファイアウォール規則確認
    Write-Host "`n5. Checking firewall rules..." -ForegroundColor Yellow
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Host "✅ Firewall rules configured" -ForegroundColor Green
    
    # 6. 設定の確認
    Write-Host "`n6. Final configuration:" -ForegroundColor Cyan
    Write-Host "WinRM Service: $($winrmStatus.Status)" -ForegroundColor White
    Write-Host "TrustedHosts: $($trustedHosts.Value)" -ForegroundColor White
    Write-Host "Network Profile: $($networkProfile.NetworkCategory)" -ForegroundColor White
    
    Write-Host "`n✅ Setup complete!" -ForegroundColor Green
    Write-Host "`nYou can now connect to 192.168.111.163 using:" -ForegroundColor Cyan
    Write-Host '$cred = Get-Credential' -ForegroundColor White
    Write-Host 'Enter-PSSession -ComputerName 192.168.111.163 -Credential $cred' -ForegroundColor White
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to exit"