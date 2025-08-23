# 調査側でリバース接続を受信するスクリプト
# 管理者権限で実行してください

param(
    [int]$SSHPort = 2222,
    [int]$ReversePort = 3333,
    [string]$Username = "investigator"
)

Write-Host "=== Investigation Server Setup ===" -ForegroundColor Green

try {
    # 現在のIPアドレス取得
    $localIP = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null}).IPv4Address.IPAddress
    Write-Host "Investigation Server IP: $localIP" -ForegroundColor Cyan
    
    # ユーザーアカウント作成（investigator）
    try {
        Get-LocalUser -Name $Username -ErrorAction Stop | Out-Null
        Write-Host "User '$Username' already exists" -ForegroundColor Yellow
    } catch {
        Write-Host "Creating user '$Username'..." -ForegroundColor Yellow
        $password = ConvertTo-SecureString "TempPass123!" -AsPlainText -Force
        New-LocalUser -Name $Username -Password $password -Description "SSH Investigation User"
        Add-LocalGroupMember -Group "Users" -Member $Username
    }
    
    # SSH公開鍵の設定
    $sshDir = "C:\Users\$Username\.ssh"
    if (!(Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force
    }
    
    # 既存の公開鍵を使用
    $publicKeyContent = Get-Content "C:\Users\hirotaka\Documents\work\auth\pc_investigation_key.pub"
    $authorizedKeysFile = "$sshDir\authorized_keys"
    $publicKeyContent | Out-File -FilePath $authorizedKeysFile -Encoding ASCII
    
    # 権限設定
    icacls $sshDir /inheritance:r
    icacls $sshDir /grant:r "${Username}:(OI)(CI)F"
    icacls $authorizedKeysFile /inheritance:r  
    icacls $authorizedKeysFile /grant:r "${Username}:F"
    
    Write-Host "✅ SSH server ready for reverse connections" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Run start_ssh_server.ps1 as Administrator" -ForegroundColor White
    Write-Host "2. Give this IP to target PC: $localIP" -ForegroundColor White
    Write-Host "3. Target PC runs: reverse_connect_script.ps1" -ForegroundColor White
    Write-Host "4. Connect to target: ssh -p $ReversePort pc@192.168.111.200" -ForegroundColor White
    
    # SSH接続待機
    Write-Host "`nWaiting for reverse connection..." -ForegroundColor Yellow
    Write-Host "Monitor with: netstat -an | findstr :$ReversePort" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run as Administrator" -ForegroundColor Yellow
}