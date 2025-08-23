# 最終検証と動作テストスクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "=======================================" -ForegroundColor Green
Write-Host "    FINAL VERIFICATION & LOAD TEST" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n1. Current Power Plan Status..." -ForegroundColor Yellow
    
    $currentStatus = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @{}
        
        # アクティブプラン確認
        $activePlan = powercfg /getactivescheme
        $results.ActivePlan = $activePlan
        
        # 利用可能プラン一覧
        $allPlans = powercfg /list
        $results.AllPlans = $allPlans
        
        return $results
    }
    
    Write-Host "Active Plan:" -ForegroundColor Cyan
    Write-Host $currentStatus.ActivePlan -ForegroundColor Green
    
    if ($currentStatus.ActivePlan -match "Thermal Protection Plan") {
        Write-Host "Power Plan Status: ACTIVE" -ForegroundColor Green
    } else {
        Write-Host "Power Plan Status: NOT ACTIVE" -ForegroundColor Red
    }
    
    Write-Host "`n2. System Load Test (30 seconds)..." -ForegroundColor Yellow
    Write-Host "Testing thermal protection under load..." -ForegroundColor Cyan
    
    $loadTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $testResults = @{}
        
        # テスト開始時の状態
        $startTime = Get-Date
        $startCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        # WMI温度チェック（可能な場合）
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $startTemp = ($temps[0].CurrentTemperature - 2732) / 10
                $testResults.StartTemp = $startTemp
            }
        } catch {
            $testResults.StartTemp = "N/A"
        }
        
        # 高負荷テスト（30秒間）
        $endTime = (Get-Date).AddSeconds(30)
        $maxCPU = 0
        
        while ((Get-Date) -lt $endTime) {
            # CPU集約的な計算
            1..100 | ForEach-Object { 
                [Math]::Sqrt($_) * [Math]::Sin($_) * [Math]::Cos($_) * [Math]::Log($_)
            } | Out-Null
            
            # CPU使用率監視
            $currentCPU = (Get-WmiObject Win32_Processor).LoadPercentage
            if ($currentCPU -gt $maxCPU) {
                $maxCPU = $currentCPU
            }
        }
        
        # テスト終了時の状態
        $endCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        $actualDuration = ((Get-Date) - $startTime).TotalSeconds
        
        # 終了時温度チェック
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $endTemp = ($temps[0].CurrentTemperature - 2732) / 10
                $testResults.EndTemp = $endTemp
            }
        } catch {
            $testResults.EndTemp = "N/A"
        }
        
        $testResults.StartCPU = $startCPU
        $testResults.MaxCPU = $maxCPU
        $testResults.EndCPU = $endCPU
        $testResults.Duration = $actualDuration
        
        return $testResults
    }
    
    Write-Host "`nLoad Test Results:" -ForegroundColor Cyan
    Write-Host "  Duration: $([math]::Round($loadTest.Duration, 1)) seconds" -ForegroundColor White
    Write-Host "  CPU Load - Start: $($loadTest.StartCPU)%" -ForegroundColor White
    Write-Host "  CPU Load - Max: $($loadTest.MaxCPU)%" -ForegroundColor White
    Write-Host "  CPU Load - End: $($loadTest.EndCPU)%" -ForegroundColor White
    
    if ($loadTest.StartTemp -ne "N/A" -and $loadTest.EndTemp -ne "N/A") {
        Write-Host "  Temperature - Start: $($loadTest.StartTemp)C" -ForegroundColor White
        Write-Host "  Temperature - End: $($loadTest.EndTemp)C" -ForegroundColor White
        $tempDiff = $loadTest.EndTemp - $loadTest.StartTemp
        Write-Host "  Temperature Change: +$([math]::Round($tempDiff, 1))C" -ForegroundColor $(
            if ($tempDiff -lt 10) { "Green" } elseif ($tempDiff -lt 20) { "Yellow" } else { "Red" }
        )
    } else {
        Write-Host "  Temperature: Not available via WMI" -ForegroundColor Gray
    }
    
    Write-Host "`n3. Post-Test System Check..." -ForegroundColor Yellow
    
    $postTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @{}
        
        # システムが正常に動作しているか確認
        $results.CurrentTime = Get-Date
        $results.CPULoad = (Get-WmiObject Win32_Processor).LoadPercentage
        
        # メモリ使用状況
        $os = Get-WmiObject Win32_OperatingSystem
        $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeMem = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedMem = $totalMem - $freeMem
        $memUsage = [math]::Round(($usedMem / $totalMem) * 100, 1)
        
        $results.MemoryUsage = "$memUsage% ($usedMem GB / $totalMem GB)"
        
        # システム稼働時間
        $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $uptime = (Get-Date) - $lastBoot
        $results.Uptime = "$($uptime.Hours)h $($uptime.Minutes)m"
        
        return $results
    }
    
    Write-Host "`nPost-Test System Status:" -ForegroundColor Cyan
    Write-Host "  Current Time: $($postTest.CurrentTime)" -ForegroundColor White
    Write-Host "  CPU Load: $($postTest.CPULoad)%" -ForegroundColor White
    Write-Host "  Memory Usage: $($postTest.MemoryUsage)" -ForegroundColor White
    Write-Host "  System Uptime: $($postTest.Uptime)" -ForegroundColor White
    
    Write-Host "`n4. Shutdown History Check..." -ForegroundColor Yellow
    
    $shutdownCheck = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        try {
            # 最新の予期しないシャットダウンを確認
            $recentShutdowns = Get-EventLog -LogName System -Source "EventLog" -EntryType Error -Newest 5 | 
                              Where-Object { $_.EventID -eq 6008 }
            
            if ($recentShutdowns) {
                $latest = $recentShutdowns[0]
                return @{
                    HasShutdowns = $true
                    LatestShutdown = $latest.TimeGenerated
                    ShutdownCount = $recentShutdowns.Count
                    TestTime = Get-Date
                }
            } else {
                return @{
                    HasShutdowns = $false
                    Message = "No unexpected shutdowns in recent logs"
                    TestTime = Get-Date
                }
            }
        } catch {
            return @{
                HasShutdowns = $false
                Message = "Could not access shutdown logs"
                TestTime = Get-Date
            }
        }
    }
    
    Write-Host "`nShutdown Analysis:" -ForegroundColor Cyan
    if ($shutdownCheck.HasShutdowns) {
        Write-Host "  Latest Unexpected Shutdown: $($shutdownCheck.LatestShutdown)" -ForegroundColor Yellow
        Write-Host "  Recent Shutdown Count: $($shutdownCheck.ShutdownCount)" -ForegroundColor Yellow
        
        # テスト中にシャットダウンが発生したかチェック
        $timeSinceShutdown = $shutdownCheck.TestTime - $shutdownCheck.LatestShutdown
        if ($timeSinceShutdown.TotalMinutes -lt 60) {
            Write-Host "  WARNING: Recent shutdown detected!" -ForegroundColor Red
        } else {
            Write-Host "  Status: No new shutdowns during test" -ForegroundColor Green
        }
    } else {
        Write-Host "  Status: No recent unexpected shutdowns" -ForegroundColor Green
    }
    
    # 総合評価
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "           FINAL ASSESSMENT" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green
    
    $assessment = @()
    
    # 電源プラン評価
    if ($currentStatus.ActivePlan -match "Thermal Protection Plan") {
        Write-Host "Thermal Protection Plan: ACTIVE" -ForegroundColor Green
        $assessment += "Plan Active"
    } else {
        Write-Host "Thermal Protection Plan: INACTIVE" -ForegroundColor Red
        $assessment += "Plan Issue"
    }
    
    # 負荷テスト評価
    if ($loadTest.MaxCPU -lt 90) {
        Write-Host "Load Test Performance: CONTROLLED ($($loadTest.MaxCPU)% max)" -ForegroundColor Green
        $assessment += "Performance Controlled"
    } else {
        Write-Host "Load Test Performance: HIGH ($($loadTest.MaxCPU)% max)" -ForegroundColor Yellow
        $assessment += "High Performance"
    }
    
    # 温度評価
    if ($loadTest.StartTemp -ne "N/A" -and $loadTest.EndTemp -ne "N/A") {
        $tempIncrease = $loadTest.EndTemp - $loadTest.StartTemp
        if ($tempIncrease -lt 15) {
            Write-Host "Temperature Control: GOOD (+$([math]::Round($tempIncrease, 1))C)" -ForegroundColor Green
            $assessment += "Temperature OK"
        } else {
            Write-Host "Temperature Control: CONCERN (+$([math]::Round($tempIncrease, 1))C)" -ForegroundColor Yellow
            $assessment += "Temperature Watch"
        }
    } else {
        Write-Host "Temperature Monitoring: Not Available" -ForegroundColor Gray
        $assessment += "Temp N/A"
    }
    
    # 安定性評価
    if (-not $shutdownCheck.HasShutdowns -or ($shutdownCheck.TestTime - $shutdownCheck.LatestShutdown).TotalHours -gt 1) {
        Write-Host "System Stability: STABLE" -ForegroundColor Green
        $assessment += "Stable"
    } else {
        Write-Host "System Stability: UNSTABLE" -ForegroundColor Red
        $assessment += "Unstable"
    }
    
    Write-Host "`nOVERALL STATUS: " -NoNewline
    if ($assessment -contains "Plan Issue" -or $assessment -contains "Unstable") {
        Write-Host "NEEDS ATTENTION" -ForegroundColor Red
    } elseif ($assessment -contains "Temperature Watch" -or $assessment -contains "High Performance") {
        Write-Host "MONITOR CLOSELY" -ForegroundColor Yellow
    } else {
        Write-Host "THERMAL PROTECTION WORKING" -ForegroundColor Green
    }
    
    Write-Host "`nRECOMMENDATIONS:" -ForegroundColor Cyan
    Write-Host "1. Continue monitoring for 24-48 hours" -ForegroundColor White
    Write-Host "2. Install HWiNFO64 for detailed temperature tracking" -ForegroundColor White
    Write-Host "3. Check for shutdown reduction compared to previous 26 incidents" -ForegroundColor White
    Write-Host "4. Clean cooling system if temperatures remain high" -ForegroundColor White
    
} catch {
    Write-Host "Final verification failed: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"