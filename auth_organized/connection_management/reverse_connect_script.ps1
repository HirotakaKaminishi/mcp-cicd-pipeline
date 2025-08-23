# 対象PC(192.168.111.163)から調査マシンへの逆接続スクリプト
# 対象PCで実行してください

param(
    [string]$InvestigationIP = "192.168.111.55",  # 調査側のIPアドレス（確認済み）
    [int]$SSHPort = 2222,
    [int]$ReversePort = 3333
)

Write-Host "=== Reverse SSH Connection Setup ===" -ForegroundColor Green
Write-Host "Target Investigation Server: $InvestigationIP:$SSHPort" -ForegroundColor Cyan

# OpenSSH Clientのインストール確認
try {
    $sshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
    
    if ($sshClient.State -ne "Installed") {
        Write-Host "Installing OpenSSH Client..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    }
    
    # SSH接続テスト
    Write-Host "Testing connection to investigation server..." -ForegroundColor Yellow
    $testResult = Test-NetConnection -ComputerName $InvestigationIP -Port $SSHPort -WarningAction SilentlyContinue
    
    if ($testResult.TcpTestSucceeded) {
        Write-Host "✅ Can reach investigation server!" -ForegroundColor Green
        
        # リバースSSHトンネル設定コマンド表示
        Write-Host "`nReverse SSH Tunnel Commands:" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor White
        
        # PowerShell経由での接続
        $reverseCmd = "ssh -R ${ReversePort}:192.168.111.200:22 -N investigator@$InvestigationIP -p $SSHPort"
        Write-Host "1. Reverse tunnel command:" -ForegroundColor Yellow
        Write-Host "   $reverseCmd" -ForegroundColor White
        
        # 調査側からの接続方法
        Write-Host "`n2. Investigation server connection:" -ForegroundColor Yellow
        Write-Host "   ssh -p $ReversePort pc@192.168.111.200" -ForegroundColor White
        
        # 自動実行オプション
        Write-Host "`n3. Auto-execute reverse tunnel? (y/n):" -ForegroundColor Yellow
        $choice = Read-Host
        
        if ($choice -eq 'y' -or $choice -eq 'Y') {
            Write-Host "Executing reverse tunnel..." -ForegroundColor Green
            Write-Host "Press Ctrl+C to stop" -ForegroundColor Red
            
            # SSH接続実行（要認証）
            & ssh -R "${ReversePort}:192.168.111.200:22" -N "investigator@$InvestigationIP" -p $SSHPort
        }
        
    } else {
        Write-Host "❌ Cannot reach investigation server" -ForegroundColor Red
        Write-Host "Check:" -ForegroundColor Yellow
        Write-Host "- Investigation server IP: $InvestigationIP" -ForegroundColor White
        Write-Host "- SSH port: $SSHPort" -ForegroundColor White
        Write-Host "- Network connectivity" -ForegroundColor White
        Write-Host "- Firewall settings" -ForegroundColor White
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 電源問題調査準備
Write-Host "`n=== Power Issue Investigation Commands ===" -ForegroundColor Green
Write-Host "After SSH connection, run these commands:" -ForegroundColor Cyan

$investigationCommands = @(
    "Get-EventLog -LogName System -EntryType Error -Newest 20 | Where-Object {`$_.Source -like '*Power*'}",
    "Get-EventLog -LogName System | Where-Object {`$_.EventID -eq 6008} | Select-Object TimeGenerated,Message -First 10",
    "powercfg /lastwake",
    "Get-WmiObject -Class Win32_SystemEnclosure | Select-Object ChassisTypes,SMBIOSAssetTag",
    "Get-Counter '\Process(*)\% Processor Time' | Select-Object -ExpandProperty CounterSamples | Sort-Object CookedValue -Descending | Select-Object -First 10"
)

foreach ($cmd in $investigationCommands) {
    Write-Host "  $cmd" -ForegroundColor White
}