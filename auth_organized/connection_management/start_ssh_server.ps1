# Portable SSH Server セットアップスクリプト
# 管理者権限で実行してください

param(
    [int]$Port = 2222,
    [string]$KeyPath = "C:\Users\hirotaka\Documents\work\auth"
)

Write-Host "=== SSH Server Setup (Port: $Port) ===" -ForegroundColor Green

# OpenSSH Serverのインストール確認・実行
try {
    # OpenSSH Server機能確認
    $sshFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    
    if ($sshFeature.State -ne "Installed") {
        Write-Host "Installing OpenSSH Server..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    }
    
    # SSH設定ディレクトリ作成
    $sshConfigDir = "C:\ProgramData\ssh"
    if (!(Test-Path $sshConfigDir)) {
        New-Item -ItemType Directory -Path $sshConfigDir -Force
    }
    
    # sshd_config設定
    $sshdConfig = @"
Port $Port
Protocol 2
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
SyslogFacility AUTH
LogLevel INFO
"@
    
    $sshdConfig | Out-File -FilePath "$sshConfigDir\sshd_config" -Encoding ASCII
    
    # ファイアウォール規則追加
    New-NetFirewallRule -DisplayName "SSH Server Port $Port" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port -ErrorAction SilentlyContinue
    
    # SSHサービス開始
    Start-Service sshd -ErrorAction SilentlyContinue
    Set-Service -Name sshd -StartupType 'Automatic' -ErrorAction SilentlyContinue
    
    Write-Host "✅ SSH Server started on port $Port" -ForegroundColor Green
    Write-Host "Connection command for target PC:" -ForegroundColor Cyan
    Write-Host "ssh -p $Port username@$(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like '192.168.*'} | Select-Object -First 1 -ExpandProperty IPAddress)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run as Administrator" -ForegroundColor Yellow
}