# SSH Shell問題修正スクリプト
# 管理者権限で実行してください

Write-Host "=== Fixing SSH Shell Configuration ===" -ForegroundColor Green

# 管理者権限確認
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Administrator privileges required" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    # 1. デフォルトシェルをPowerShellに設定
    Write-Host "`n1. Setting default shell to PowerShell..." -ForegroundColor Yellow
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
    Write-Host "✅ Default shell set to PowerShell" -ForegroundColor Green
    
    # 2. SSH設定ファイルの場所確認
    Write-Host "`n2. Checking SSH configuration..." -ForegroundColor Yellow
    $sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
    
    if (Test-Path $sshdConfigPath) {
        Write-Host "✅ Found sshd_config at: $sshdConfigPath" -ForegroundColor Green
        
        # バックアップ作成
        $backupPath = "$sshdConfigPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $sshdConfigPath -Destination $backupPath
        Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
        
        # 設定内容確認
        $config = Get-Content $sshdConfigPath
        
        # Subsystem設定確認
        $sftpLine = $config | Where-Object {$_ -like "*Subsystem*sftp*"}
        if ($sftpLine) {
            Write-Host "✅ SFTP subsystem configured" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ sshd_config not found at default location" -ForegroundColor Yellow
        
        # 代替場所確認
        $altPath = "C:\Program Files (x86)\OpenSSH\sshd_config"
        if (Test-Path $altPath) {
            Write-Host "Found at: $altPath" -ForegroundColor White
        }
    }
    
    # 3. ユーザー権限確認
    Write-Host "`n3. Checking user permissions..." -ForegroundColor Yellow
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Current user: $currentUser" -ForegroundColor White
    
    # Administratorsグループにユーザーを追加
    try {
        Add-LocalGroupMember -Group "Administrators" -Member "hirotaka" -ErrorAction SilentlyContinue
        Write-Host "✅ User 'hirotaka' is in Administrators group" -ForegroundColor Green
    } catch {
        Write-Host "User already in group or doesn't exist" -ForegroundColor Gray
    }
    
    # 4. SSHサービス再起動
    Write-Host "`n4. Restarting SSH service..." -ForegroundColor Yellow
    Restart-Service sshd
    Start-Sleep -Seconds 2
    $service = Get-Service sshd
    Write-Host "✅ SSH service status: $($service.Status)" -ForegroundColor Green
    
    # 5. ファイアウォール確認
    Write-Host "`n5. Checking firewall rules..." -ForegroundColor Yellow
    $rules = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*SSH*" -or $_.DisplayName -like "*OpenSSH*"}
    foreach ($rule in $rules) {
        Write-Host "  - $($rule.DisplayName): $($rule.Enabled)" -ForegroundColor White
    }
    
    Write-Host "`n✅ Configuration fixed!" -ForegroundColor Green
    Write-Host "`nPlease try connecting again from target PC:" -ForegroundColor Cyan
    Write-Host "ssh -R 3333:localhost:22 hirotaka@192.168.111.55" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"