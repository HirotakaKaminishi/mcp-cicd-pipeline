# 対象PC再起動スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "======================================" -ForegroundColor Yellow
Write-Host "       TARGET PC RESTART" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow
Write-Host "Target: $targetPC (WINDOWS-8R73QDH)" -ForegroundColor Cyan

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n⚠️  WARNING: System restart will be initiated!" -ForegroundColor Red
    Write-Host "This will test the thermal protection settings after reboot." -ForegroundColor Yellow
    
    Write-Host "`n1. Pre-restart system status check..." -ForegroundColor Yellow
    
    $preRestartStatus = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $status = @{}
        
        # 現在のアクティブプラン確認
        $activePlan = powercfg /getactivescheme
        $status.ActivePlan = $activePlan
        
        # システム稼働時間
        $os = Get-WmiObject Win32_OperatingSystem
        $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $uptime = (Get-Date) - $lastBoot
        $status.CurrentUptime = "$($uptime.Hours)h $($uptime.Minutes)m"
        $status.LastBootTime = $lastBoot
        
        # システム時刻
        $status.CurrentTime = Get-Date
        
        return $status
    }
    
    Write-Host "`nCurrent Status:" -ForegroundColor Cyan
    Write-Host "  Active Plan: $($preRestartStatus.ActivePlan)" -ForegroundColor Green
    Write-Host "  Current Uptime: $($preRestartStatus.CurrentUptime)" -ForegroundColor White
    Write-Host "  Last Boot: $($preRestartStatus.LastBootTime)" -ForegroundColor White
    Write-Host "  Current Time: $($preRestartStatus.CurrentTime)" -ForegroundColor White
    
    Write-Host "`n2. Initiating restart..." -ForegroundColor Yellow
    Write-Host "⏰ Restart will begin in 10 seconds..." -ForegroundColor Red
    
    # 10秒のカウントダウン
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host "   $i..." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
    
    # 再起動実行
    Write-Host "`n🔄 Executing restart command..." -ForegroundColor Red
    
    $restartResult = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        # 1分後に再起動（緊急停止を避けるため）
        shutdown /r /t 60 /c "Thermal protection configuration test - restart initiated by remote management"
        return "Restart command executed successfully"
    }
    
    Write-Host "✅ $restartResult" -ForegroundColor Green
    Write-Host "`n📋 Restart Details:" -ForegroundColor Cyan
    Write-Host "  - Restart scheduled in 60 seconds" -ForegroundColor White
    Write-Host "  - Reason: Thermal protection configuration test" -ForegroundColor White
    Write-Host "  - Expected downtime: 2-3 minutes" -ForegroundColor White
    
    Write-Host "`n⏳ Waiting for system shutdown..." -ForegroundColor Yellow
    
    # システムがシャットダウンするまで待機
    $shutdownDetected = $false
    $maxWaitTime = 120 # 最大2分待機
    $startWait = Get-Date
    
    while (((Get-Date) - $startWait).TotalSeconds -lt $maxWaitTime -and -not $shutdownDetected) {
        try {
            # 接続テスト
            $testConnection = Test-Connection -ComputerName $targetPC -Count 1 -Quiet -ErrorAction SilentlyContinue
            if (-not $testConnection) {
                $shutdownDetected = $true
                Write-Host "🔌 System shutdown detected" -ForegroundColor Yellow
            } else {
                Write-Host "." -NoNewline -ForegroundColor Gray
                Start-Sleep -Seconds 5
            }
        } catch {
            $shutdownDetected = $true
            Write-Host "`n🔌 System shutdown detected" -ForegroundColor Yellow
        }
    }
    
    if ($shutdownDetected) {
        Write-Host "`n✅ System has shut down successfully" -ForegroundColor Green
        Write-Host "`n⏳ Waiting for system to restart..." -ForegroundColor Yellow
        Write-Host "This may take 2-5 minutes depending on hardware..." -ForegroundColor Gray
        
        # システムが再起動するまで待機
        $restartDetected = $false
        $maxRestartWait = 300 # 最大5分待機
        $startRestartWait = Get-Date
        
        while (((Get-Date) - $startRestartWait).TotalSeconds -lt $maxRestartWait -and -not $restartDetected) {
            try {
                Start-Sleep -Seconds 15
                $testConnection = Test-Connection -ComputerName $targetPC -Count 1 -Quiet -ErrorAction SilentlyContinue
                if ($testConnection) {
                    # 追加確認：PowerShellリモーティングが利用可能か
                    try {
                        $testPS = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock { 
                            return "Online" 
                        } -ErrorAction Stop
                        
                        if ($testPS -eq "Online") {
                            $restartDetected = $true
                            Write-Host "`n🟢 System restart completed!" -ForegroundColor Green
                        }
                    } catch {
                        Write-Host "⏳" -NoNewline -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "." -NoNewline -ForegroundColor Gray
                }
            } catch {
                Write-Host "." -NoNewline -ForegroundColor Gray
            }
        }
        
        if ($restartDetected) {
            Write-Host "`n🎉 RESTART SUCCESSFUL!" -ForegroundColor Green
            
            # 再起動後の状態確認
            Write-Host "`n3. Post-restart verification..." -ForegroundColor Yellow
            
            Start-Sleep -Seconds 10  # 少し待ってからチェック
            
            $postRestartStatus = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
                $status = @{}
                
                # 再起動後のアクティブプラン確認
                $activePlan = powercfg /getactivescheme
                $status.ActivePlan = $activePlan
                
                # 新しい起動時間
                $os = Get-WmiObject Win32_OperatingSystem
                $newBootTime = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
                $newUptime = (Get-Date) - $newBootTime
                $status.NewBootTime = $newBootTime
                $status.NewUptime = "$($newUptime.Hours)h $($newUptime.Minutes)m"
                
                # システム基本情報
                $status.CurrentTime = Get-Date
                $status.ComputerName = $env:COMPUTERNAME
                
                return $status
            }
            
            Write-Host "`nPost-Restart Status:" -ForegroundColor Cyan
            Write-Host "  Computer Name: $($postRestartStatus.ComputerName)" -ForegroundColor White
            Write-Host "  New Boot Time: $($postRestartStatus.NewBootTime)" -ForegroundColor Green
            Write-Host "  Current Uptime: $($postRestartStatus.NewUptime)" -ForegroundColor White
            Write-Host "  Current Time: $($postRestartStatus.CurrentTime)" -ForegroundColor White
            Write-Host "`n  Active Power Plan:" -ForegroundColor Cyan
            Write-Host "  $($postRestartStatus.ActivePlan)" -ForegroundColor Green
            
            # 電源プランが正しく適用されているか確認
            if ($postRestartStatus.ActivePlan -match "Thermal Protection Plan") {
                Write-Host "`n✅ SUCCESS: Thermal Protection Plan survived restart!" -ForegroundColor Green
                Write-Host "🛡️  Thermal protection is active after reboot" -ForegroundColor Green
            } else {
                Write-Host "`n⚠️  WARNING: Thermal Protection Plan not active after restart" -ForegroundColor Red
                Write-Host "📋 Manual reactivation may be required" -ForegroundColor Yellow
            }
            
        } else {
            Write-Host "`n❌ TIMEOUT: System did not restart within expected time" -ForegroundColor Red
            Write-Host "🔍 Please check system status manually" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "`n❌ TIMEOUT: System did not shut down within expected time" -ForegroundColor Red
        Write-Host "🔍 Please check system status manually" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "`n❌ Restart operation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔍 Please check system connectivity and try manual restart" -ForegroundColor Yellow
}

Write-Host "`n" + "=" * 50 -ForegroundColor Green
Write-Host "         RESTART OPERATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

Read-Host "`nPress Enter to continue"