# OpenSSH Server 完全インストールスクリプト
# 管理者権限で実行してください

Write-Host "=== OpenSSH Server Installation ===" -ForegroundColor Green

try {
    # 管理者権限確認
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "❌ This script requires Administrator privileges" -ForegroundColor Red
        Write-Host "Please run as Administrator" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host "✅ Running with Administrator privileges" -ForegroundColor Green
    
    # OpenSSH Server機能確認
    Write-Host "`n1. Checking OpenSSH Server feature..." -ForegroundColor Yellow
    $sshFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    
    if ($sshFeature.State -eq "Installed") {
        Write-Host "✅ OpenSSH Server already installed" -ForegroundColor Green
    } else {
        Write-Host "📦 Installing OpenSSH Server..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Write-Host "✅ OpenSSH Server installed" -ForegroundColor Green
    }
    
    # サービス設定
    Write-Host "`n2. Configuring SSH service..." -ForegroundColor Yellow
    
    # サービス開始
    Start-Service sshd
    Write-Host "✅ SSH service started" -ForegroundColor Green
    
    # 自動起動設定
    Set-Service -Name sshd -StartupType 'Automatic'
    Write-Host "✅ SSH service set to automatic startup" -ForegroundColor Green
    
    # SSH Agent も設定
    Start-Service ssh-agent
    Set-Service -Name ssh-agent -StartupType 'Automatic'
    Write-Host "✅ SSH Agent configured" -ForegroundColor Green
    
    # ファイアウォール設定
    Write-Host "`n3. Configuring firewall..." -ForegroundColor Yellow
    
    # 既存の規則があるかチェック
    $existingRule = Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue
    if (-not $existingRule) {
        New-NetFirewallRule -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
        Write-Host "✅ Firewall rule for port 22 created" -ForegroundColor Green
    } else {
        Write-Host "✅ Firewall rule for port 22 already exists" -ForegroundColor Green
    }
    
    # 調査用ポート2222
    $existingRule2222 = Get-NetFirewallRule -DisplayName "SSH Investigation Port" -ErrorAction SilentlyContinue
    if (-not $existingRule2222) {
        New-NetFirewallRule -DisplayName 'SSH Investigation Port' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2222
        Write-Host "✅ Firewall rule for port 2222 created" -ForegroundColor Green
    } else {
        Write-Host "✅ Firewall rule for port 2222 already exists" -ForegroundColor Green
    }
    
    # 状態確認
    Write-Host "`n4. Final status check..." -ForegroundColor Yellow
    $sshdService = Get-Service -Name "sshd"
    Write-Host "   SSH Service Status: $($sshdService.Status)" -ForegroundColor White
    Write-Host "   SSH Service StartType: $($sshdService.StartType)" -ForegroundColor White
    
    # 接続テスト
    Write-Host "`n5. Testing connection..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    $testResult = Test-NetConnection -ComputerName localhost -Port 22 -WarningAction SilentlyContinue
    if ($testResult.TcpTestSucceeded) {
        Write-Host "✅ SSH server is listening on port 22" -ForegroundColor Green
    } else {
        Write-Host "❌ SSH server is not responding on port 22" -ForegroundColor Red
    }
    
    Write-Host "`n🎉 SSH Server setup complete!" -ForegroundColor Green
    Write-Host "You can now accept reverse SSH connections from the target PC" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"