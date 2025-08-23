# Force Install OpenSSH Server
# 必ず管理者権限で実行してください

Write-Host "=== Force Install OpenSSH Server ===" -ForegroundColor Green

# 管理者権限確認
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ MUST run as Administrator!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    Write-Host "🔍 Checking current OpenSSH features..." -ForegroundColor Yellow
    
    # 現在の状態確認
    $clientFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
    $serverFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    
    Write-Host "Client Status: $($clientFeature.State)" -ForegroundColor White
    Write-Host "Server Status: $($serverFeature.State)" -ForegroundColor White
    
    # OpenSSH Serverのインストール
    if ($serverFeature.State -ne "Installed") {
        Write-Host "📦 Installing OpenSSH Server..." -ForegroundColor Yellow
        $result = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Write-Host "Installation Result: $($result.RestartNeeded)" -ForegroundColor White
        
        # 再確認
        Start-Sleep -Seconds 2
        $serverFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
        Write-Host "New Server Status: $($serverFeature.State)" -ForegroundColor White
    }
    
    # ファイル確認
    Write-Host "`n🔍 Checking SSH files..." -ForegroundColor Yellow
    $sshdPath = "C:\Windows\System32\OpenSSH\sshd.exe"
    if (Test-Path $sshdPath) {
        Write-Host "✅ sshd.exe found at $sshdPath" -ForegroundColor Green
    } else {
        Write-Host "❌ sshd.exe not found" -ForegroundColor Red
    }
    
    # サービス確認
    Write-Host "`n🔍 Checking SSH services..." -ForegroundColor Yellow
    $sshdService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
    if ($sshdService) {
        Write-Host "✅ SSH service exists: $($sshdService.Status)" -ForegroundColor Green
    } else {
        Write-Host "❌ SSH service not found" -ForegroundColor Red
        
        # サービス手動作成を試行
        Write-Host "🔧 Attempting to create SSH service..." -ForegroundColor Yellow
        if (Test-Path $sshdPath) {
            New-Service -Name sshd -BinaryPathName $sshdPath -DisplayName "OpenSSH SSH Server" -StartupType Manual -ErrorAction SilentlyContinue
            $sshdService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
            if ($sshdService) {
                Write-Host "✅ SSH service created successfully" -ForegroundColor Green
            }
        }
    }
    
    Write-Host "`n📋 Current Status Summary:" -ForegroundColor Cyan
    Write-Host "OpenSSH Server Feature: $($serverFeature.State)" -ForegroundColor White
    Write-Host "sshd.exe exists: $(Test-Path $sshdPath)" -ForegroundColor White
    Write-Host "SSH service exists: $($sshdService -ne $null)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full Error: $_" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"