# 対象PC(192.168.111.163)から調査側(192.168.111.55)への簡易逆接続スクリプト
# USBメモリなどで対象PCに転送して実行してください

param(
    [string]$InvestigationIP = "192.168.111.55",
    [int]$SSHPort = 2222,
    [int]$ReversePort = 3333
)

Write-Host "=== Quick Reverse SSH Setup ===" -ForegroundColor Green
Write-Host "Investigation Server: $InvestigationIP:$SSHPort" -ForegroundColor Cyan
Write-Host "Reverse Port: $ReversePort" -ForegroundColor Yellow

try {
    # OpenSSH Clientの確認とインストール
    Write-Host "`nChecking OpenSSH Client..." -ForegroundColor Yellow
    $sshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
    
    if ($sshClient.State -ne "Installed") {
        Write-Host "Installing OpenSSH Client..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
        Write-Host "✅ OpenSSH Client installed" -ForegroundColor Green
    } else {
        Write-Host "✅ OpenSSH Client already installed" -ForegroundColor Green
    }
    
    # 接続テスト
    Write-Host "`nTesting connection to $InvestigationIP:$SSHPort..." -ForegroundColor Yellow
    $testResult = Test-NetConnection -ComputerName $InvestigationIP -Port $SSHPort -WarningAction SilentlyContinue
    
    if ($testResult.TcpTestSucceeded) {
        Write-Host "✅ Connection successful!" -ForegroundColor Green
        
        # リバースSSHコマンドの表示
        Write-Host "`n📋 Reverse SSH Commands:" -ForegroundColor Cyan
        Write-Host "=" * 50 -ForegroundColor White
        
        $sshKey = "C:\temp\pc_investigation_key"
        $reverseCmd = "ssh -R ${ReversePort}:localhost:22 -i `"$sshKey`" -N investigator@$InvestigationIP -p $SSHPort"
        
        Write-Host "1. Reverse tunnel:" -ForegroundColor Yellow
        Write-Host "   $reverseCmd" -ForegroundColor White
        
        Write-Host "`n2. Investigation access:" -ForegroundColor Yellow
        Write-Host "   ssh -p $ReversePort pc@localhost" -ForegroundColor White
        
        # 自動実行確認
        Write-Host "`n🚀 Execute reverse tunnel now? (y/n): " -ForegroundColor Green -NoNewline
        $choice = Read-Host
        
        if ($choice -eq 'y' -or $choice -eq 'Y') {
            Write-Host "Starting reverse tunnel..." -ForegroundColor Green
            Write-Host "Keep this window open. Press Ctrl+C to stop." -ForegroundColor Red
            
            # SSH実行（キーファイルが存在する場合）
            if (Test-Path $sshKey) {
                & ssh -R "${ReversePort}:localhost:22" -i "$sshKey" -N "investigator@$InvestigationIP" -p $SSHPort
            } else {
                # キーファイルなしで実行（パスワード認証）
                Write-Host "SSH key not found, using password authentication..." -ForegroundColor Yellow
                & ssh -R "${ReversePort}:localhost:22" -N "investigator@$InvestigationIP" -p $SSHPort
            }
        }
        
    } else {
        Write-Host "❌ Cannot connect to investigation server" -ForegroundColor Red
        Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
        Write-Host "- Check IP: $InvestigationIP" -ForegroundColor White
        Write-Host "- Check port: $SSHPort" -ForegroundColor White
        Write-Host "- Check firewall on both sides" -ForegroundColor White
        Write-Host "- Ensure investigation server SSH is running" -ForegroundColor White
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Run as Administrator if needed" -ForegroundColor Yellow
}

Write-Host "`n📊 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Keep this reverse tunnel running" -ForegroundColor White
Write-Host "2. Investigation side can now connect:" -ForegroundColor White
Write-Host "   ssh -p $ReversePort pc@localhost" -ForegroundColor Gray
Write-Host "3. Run power investigation commands" -ForegroundColor White