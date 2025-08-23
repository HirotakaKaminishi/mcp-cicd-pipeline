# 電源設定確認と動作検証スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "======================================" -ForegroundColor Green
Write-Host "  THERMAL PROTECTION VERIFICATION" -ForegroundColor Green  
Write-Host "======================================" -ForegroundColor Green

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n1. Power Plan Configuration Check..." -ForegroundColor Yellow
    
    $powerConfig = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @{}
        
        # アクティブプラン確認
        $activePlan = powercfg /getactivescheme
        $results.ActivePlan = $activePlan
        
        # CPU最大パフォーマンス設定確認
        $cpuMaxQuery = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTMAX
        $results.CPUMaxQuery = $cpuMaxQuery
        
        # ターボブースト設定確認
        $turboQuery = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE  
        $results.TurboQuery = $turboQuery
        
        # 設定値の抽出
        if ($cpuMaxQuery -match "AC.*0x([0-9a-f]+)") {
            $results.CPUMaxAC = [Convert]::ToInt32($matches[1], 16)
        }
        if ($cpuMaxQuery -match "DC.*0x([0-9a-f]+)") {
            $results.CPUMaxDC = [Convert]::ToInt32($matches[1], 16)
        }
        if ($turboQuery -match "AC.*0x([0-9a-f]+)") {
            $results.TurboAC = [Convert]::ToInt32($matches[1], 16)
        }
        if ($turboQuery -match "DC.*0x([0-9a-f]+)") {
            $results.TurboDC = [Convert]::ToInt32($matches[1], 16)
        }
        
        return $results
    }
    
    # 結果表示
    Write-Host "`nActive Power Plan:" -ForegroundColor Cyan
    Write-Host $powerConfig.ActivePlan -ForegroundColor Green
    
    Write-Host "`nCPU Performance Settings:" -ForegroundColor Cyan
    if ($powerConfig.CPUMaxAC -eq 85) {
        Write-Host "  CPU Max (AC): $($powerConfig.CPUMaxAC)% - CORRECT" -ForegroundColor Green
    } else {
        Write-Host "  CPU Max (AC): $($powerConfig.CPUMaxAC)% - EXPECTED: 85%" -ForegroundColor Red
    }
    
    if ($powerConfig.CPUMaxDC -eq 80) {
        Write-Host "  CPU Max (DC): $($powerConfig.CPUMaxDC)% - CORRECT" -ForegroundColor Green
    } else {
        Write-Host "  CPU Max (DC): $($powerConfig.CPUMaxDC)% - EXPECTED: 80%" -ForegroundColor Red
    }
    
    Write-Host "`nTurbo Boost Settings:" -ForegroundColor Cyan
    if ($powerConfig.TurboAC -eq 0) {
        Write-Host "  Turbo Boost (AC): DISABLED - SAFE" -ForegroundColor Green
    } else {
        Write-Host "  Turbo Boost (AC): ENABLED - RISK" -ForegroundColor Red
    }
    
    if ($powerConfig.TurboDC -eq 0) {
        Write-Host "  Turbo Boost (DC): DISABLED - SAFE" -ForegroundColor Green  
    } else {
        Write-Host "  Turbo Boost (DC): ENABLED - RISK" -ForegroundColor Red
    }
    
    Write-Host "`n2. Performance Test..." -ForegroundColor Yellow
    
    $performanceTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $testResults = @{}
        
        $startTime = Get-Date
        $startCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        # CPU負荷テスト
        1..3000 | ForEach-Object { [Math]::Sqrt($_) * [Math]::Sin($_) } | Out-Null
        
        $endTime = Get-Date
        $endCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        $testResults.Duration = ($endTime - $startTime).TotalMilliseconds
        $testResults.StartCPU = $startCPU
        $testResults.EndCPU = $endCPU
        
        return $testResults
    }
    
    Write-Host "`nPerformance Test Results:" -ForegroundColor Cyan
    Write-Host "  Test Duration: $([math]::Round($performanceTest.Duration, 2)) ms" -ForegroundColor White
    Write-Host "  CPU Load (Start): $($performanceTest.StartCPU)%" -ForegroundColor White
    Write-Host "  CPU Load (End): $($performanceTest.EndCPU)%" -ForegroundColor White
    
    Write-Host "`n3. Temperature Check..." -ForegroundColor Yellow
    
    $tempCheck = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $tempResults = @{}
        
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $tempList = @()
                foreach ($temp in $temps) {
                    $celsius = ($temp.CurrentTemperature - 2732) / 10
                    $tempList += "Zone: $celsius C"
                }
                $tempResults.Temperatures = $tempList
            } else {
                $tempResults.Temperatures = "WMI temperature not available"
            }
        } catch {
            $tempResults.Temperatures = "Temperature check failed"
        }
        
        # システム稼働時間
        $os = Get-WmiObject Win32_OperatingSystem
        $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $uptime = (Get-Date) - $lastBoot
        $tempResults.Uptime = "$($uptime.Hours)h $($uptime.Minutes)m"
        
        return $tempResults
    }
    
    Write-Host "`nTemperature Status:" -ForegroundColor Cyan
    if ($tempCheck.Temperatures -is [array]) {
        foreach ($temp in $tempCheck.Temperatures) {
            Write-Host "  $temp" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  $($tempCheck.Temperatures)" -ForegroundColor Gray
    }
    Write-Host "  System Uptime: $($tempCheck.Uptime)" -ForegroundColor White
    
    Write-Host "`n4. Stability Check..." -ForegroundColor Yellow
    
    $stabilityCheck = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        # 最新の予期しないシャットダウンをチェック
        try {
            $latestShutdown = Get-EventLog -LogName System -Source "EventLog" -EntryType Error -Newest 1 | 
                             Where-Object { $_.EventID -eq 6008 }
            
            if ($latestShutdown) {
                return @{
                    HasRecentShutdown = $true
                    LastShutdown = $latestShutdown.TimeGenerated
                }
            } else {
                return @{
                    HasRecentShutdown = $false
                    Message = "No recent unexpected shutdowns"
                }
            }
        } catch {
            return @{
                HasRecentShutdown = $false
                Message = "Could not check shutdown history"
            }
        }
    }
    
    Write-Host "`nStability Status:" -ForegroundColor Cyan
    if ($stabilityCheck.HasRecentShutdown) {
        Write-Host "  Last Unexpected Shutdown: $($stabilityCheck.LastShutdown)" -ForegroundColor Yellow
    } else {
        Write-Host "  No Recent Unexpected Shutdowns" -ForegroundColor Green
    }
    
    # 総合評価
    Write-Host "`n" + "=" * 50 -ForegroundColor Green
    Write-Host "         VERIFICATION SUMMARY" -ForegroundColor Green
    Write-Host "=" * 50 -ForegroundColor Green
    
    $issues = @()
    
    if ($powerConfig.ActivePlan -match "Thermal Protection Plan") {
        Write-Host "Power Plan: Thermal Protection Plan ACTIVE" -ForegroundColor Green
    } else {
        Write-Host "Power Plan: NOT using Thermal Protection Plan" -ForegroundColor Red
        $issues += "Power plan not active"
    }
    
    if ($powerConfig.CPUMaxAC -eq 85 -and $powerConfig.CPUMaxDC -eq 80) {
        Write-Host "CPU Limits: Correctly configured" -ForegroundColor Green
    } else {
        Write-Host "CPU Limits: Not properly configured" -ForegroundColor Red
        $issues += "CPU limits incorrect"
    }
    
    if ($powerConfig.TurboAC -eq 0 -and $powerConfig.TurboDC -eq 0) {
        Write-Host "Turbo Boost: Properly disabled" -ForegroundColor Green
    } else {
        Write-Host "Turbo Boost: Still enabled (thermal risk)" -ForegroundColor Yellow
        $issues += "Turbo boost still enabled"
    }
    
    if ($issues.Count -eq 0) {
        Write-Host "`nOVERALL STATUS: GOOD" -ForegroundColor Green
        Write-Host "Thermal protection is properly configured!" -ForegroundColor Green
    } else {
        Write-Host "`nOVERALL STATUS: NEEDS ATTENTION" -ForegroundColor Red
        Write-Host "Issues found: $($issues -join ', ')" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Verification failed: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"