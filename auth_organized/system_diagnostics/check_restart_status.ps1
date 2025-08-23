# 再起動後の状態確認スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "======================================" -ForegroundColor Green
Write-Host "    POST-RESTART STATUS CHECK" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host "`nChecking target PC connectivity..." -ForegroundColor Yellow

# 最大10回試行
for ($attempt = 1; $attempt -le 10; $attempt++) {
    Write-Host "Attempt $attempt/10..." -ForegroundColor Cyan
    
    try {
        # ネットワーク接続テスト
        $pingTest = Test-Connection -ComputerName $targetPC -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        if ($pingTest) {
            Write-Host "  Network: ONLINE" -ForegroundColor Green
            
            # PowerShellリモーティングテスト
            try {
                $remoteTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock { 
                    return @{
                        ComputerName = $env:COMPUTERNAME
                        CurrentTime = Get-Date
                        Uptime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime)
                    }
                } -ErrorAction Stop
                
                Write-Host "  PowerShell Remoting: ONLINE" -ForegroundColor Green
                Write-Host "`n🎉 TARGET PC IS ONLINE!" -ForegroundColor Green
                Write-Host "Computer Name: $($remoteTest.ComputerName)" -ForegroundColor White
                Write-Host "System Time: $($remoteTest.CurrentTime)" -ForegroundColor White
                Write-Host "Uptime: $($remoteTest.Uptime.Hours)h $($remoteTest.Uptime.Minutes)m" -ForegroundColor White
                
                # 電源プラン確認
                Write-Host "`nChecking power plan status..." -ForegroundColor Yellow
                
                $powerStatus = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
                    $activePlan = powercfg /getactivescheme
                    return $activePlan
                }
                
                Write-Host "`nActive Power Plan:" -ForegroundColor Cyan
                Write-Host $powerStatus -ForegroundColor Green
                
                if ($powerStatus -match "Thermal Protection Plan") {
                    Write-Host "`n✅ SUCCESS: Thermal Protection Plan is ACTIVE after restart!" -ForegroundColor Green
                    Write-Host "🛡️  System is protected against thermal shutdowns" -ForegroundColor Green
                } else {
                    Write-Host "`n⚠️  WARNING: Thermal Protection Plan is NOT active" -ForegroundColor Red
                    Write-Host "📋 The plan may need to be manually reactivated" -ForegroundColor Yellow
                }
                
                # 成功したので終了
                break
                
            } catch {
                Write-Host "  PowerShell Remoting: NOT READY" -ForegroundColor Yellow
                Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  Network: NO RESPONSE" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "  Connection Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    if ($attempt -lt 10) {
        Write-Host "  Waiting 15 seconds before next attempt..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
    }
}

if ($attempt -gt 10) {
    Write-Host "`n❌ TIMEOUT: Could not establish connection after 10 attempts" -ForegroundColor Red
    Write-Host "🔍 Please check target PC status manually" -ForegroundColor Yellow
    Write-Host "`nPossible issues:" -ForegroundColor Yellow
    Write-Host "- System is still booting (may take longer)" -ForegroundColor White
    Write-Host "- Network connectivity issues" -ForegroundColor White
    Write-Host "- PowerShell remoting disabled after restart" -ForegroundColor White
    Write-Host "- System encountered boot problems" -ForegroundColor White
}

Write-Host "`n" + "=" * 50 -ForegroundColor Green
Write-Host "     RESTART STATUS CHECK COMPLETE" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

Read-Host "`nPress Enter to continue"