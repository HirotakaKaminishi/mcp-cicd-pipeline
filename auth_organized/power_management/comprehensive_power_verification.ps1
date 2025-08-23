# 包括的な電源設定確認と動作検証スクリプト
# 対象PC: 192.168.111.163 (WINDOWS-8R73QDH)

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  THERMAL PROTECTION VERIFICATION" -ForegroundColor Green  
Write-Host "========================================" -ForegroundColor Green
Write-Host "Target: $targetPC (AMD Ryzen 9 6900HX)" -ForegroundColor Cyan

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n1️⃣ Power Plan Configuration Check..." -ForegroundColor Yellow
    
    $powerConfig = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @{}
        
        # アクティブプラン確認
        $activePlan = powercfg /getactivescheme
        $results.ActivePlan = $activePlan
        
        # CPU最大パフォーマンス設定 (16進数から10進数に変換)
        $cpuMaxSettings = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTMAX
        $results.CPUMaxRaw = $cpuMaxSettings
        
        # AC電源時のCPU最大パフォーマンス
        if ($cpuMaxSettings -match "AC 電源設定インデックス: 0x([0-9a-f]+)") {
            $results.CPUMaxAC = [Convert]::ToInt32($matches[1], 16)
        }
        
        # DC電源時のCPU最大パフォーマンス  
        if ($cpuMaxSettings -match "DC 電源設定インデックス: 0x([0-9a-f]+)") {
            $results.CPUMaxDC = [Convert]::ToInt32($matches[1], 16)
        }
        
        # CPU最小パフォーマンス設定
        $cpuMinSettings = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTMIN
        if ($cpuMinSettings -match "AC 電源設定インデックス: 0x([0-9a-f]+)") {
            $results.CPUMinAC = [Convert]::ToInt32($matches[1], 16)
        }
        if ($cpuMinSettings -match "DC 電源設定インデックス: 0x([0-9a-f]+)") {
            $results.CPUMinDC = [Convert]::ToInt32($matches[1], 16)
        }
        
        # ターボブースト設定
        $turboSettings = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE
        if ($turboSettings -match "AC 電源設定インデックス: 0x([0-9a-f]+)") {
            $results.TurboAC = [Convert]::ToInt32($matches[1], 16)
        }
        if ($turboSettings -match "DC 電源設定インデックス: 0x([0-9a-f]+)") {
            $results.TurboDC = [Convert]::ToInt32($matches[1], 16)
        }
        
        # システム冷却ポリシー
        $coolingSettings = powercfg /query SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL
        if ($coolingSettings -match "AC 電源設定インデックス: 0x([0-9a-f]+)") {
            $results.CoolingAC = [Convert]::ToInt32($matches[1], 16)
        }
        
        return $results
    }
    
    # 結果表示と検証
    Write-Host "`n📋 Current Active Plan:" -ForegroundColor Cyan
    Write-Host "   $($powerConfig.ActivePlan)" -ForegroundColor Green
    
    Write-Host "`n🔧 CPU Performance Settings:" -ForegroundColor Cyan
    
    # CPU最大パフォーマンス確認
    if ($powerConfig.CPUMaxAC -eq 85) {
        Write-Host "   ✅ CPU Max (AC): $($powerConfig.CPUMaxAC)% - CORRECT" -ForegroundColor Green
    } else {
        Write-Host "   ❌ CPU Max (AC): $($powerConfig.CPUMaxAC)% - EXPECTED: 85%" -ForegroundColor Red
    }
    
    if ($powerConfig.CPUMaxDC -eq 80) {
        Write-Host "   ✅ CPU Max (DC): $($powerConfig.CPUMaxDC)% - CORRECT" -ForegroundColor Green
    } else {
        Write-Host "   ❌ CPU Max (DC): $($powerConfig.CPUMaxDC)% - EXPECTED: 80%" -ForegroundColor Red
    }
    
    # CPU最小パフォーマンス確認
    if ($powerConfig.CPUMinAC -eq 10) {
        Write-Host "   ✅ CPU Min (AC): $($powerConfig.CPUMinAC)% - CORRECT" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  CPU Min (AC): $($powerConfig.CPUMinAC)% - EXPECTED: 10%" -ForegroundColor Yellow
    }
    
    if ($powerConfig.CPUMinDC -eq 5) {
        Write-Host "   ✅ CPU Min (DC): $($powerConfig.CPUMinDC)% - CORRECT" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  CPU Min (DC): $($powerConfig.CPUMinDC)% - EXPECTED: 5%" -ForegroundColor Yellow
    }
    
    # ターボブースト確認
    Write-Host "`n🚀 Turbo Boost Settings:" -ForegroundColor Cyan
    if ($powerConfig.TurboAC -eq 0) {
        Write-Host "   ✅ Turbo Boost (AC): DISABLED - SAFE FOR THERMAL" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Turbo Boost (AC): ENABLED - THERMAL RISK" -ForegroundColor Red
    }
    
    if ($powerConfig.TurboDC -eq 0) {
        Write-Host "   ✅ Turbo Boost (DC): DISABLED - SAFE FOR THERMAL" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Turbo Boost (DC): ENABLED - THERMAL RISK" -ForegroundColor Red
    }
    
    # 冷却ポリシー確認
    Write-Host "`n❄️  Cooling Policy:" -ForegroundColor Cyan
    if ($powerConfig.CoolingAC -eq 1) {
        Write-Host "   ✅ System Cooling (AC): ACTIVE - OPTIMAL" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  System Cooling (AC): PASSIVE" -ForegroundColor Yellow
    }
    
    Write-Host "`n2️⃣ System Performance Test..." -ForegroundColor Yellow
    
    $performanceTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $testResults = @{}
        
        # ベースライン測定
        $startTime = Get-Date
        $startCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        # 軽い計算負荷テスト
        Write-Host "   Performing CPU load test..."
        1..5000 | ForEach-Object { [Math]::Sqrt($_) * [Math]::Sin($_) } | Out-Null
        
        $endTime = Get-Date
        $endCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        $testResults.TestDuration = ($endTime - $startTime).TotalMilliseconds
        $testResults.StartCPU = $startCPU
        $testResults.EndCPU = $endCPU
        $testResults.SystemInfo = Get-WmiObject Win32_ComputerSystem | Select-Object Name, TotalPhysicalMemory
        
        return $testResults
    }
    
    Write-Host "`n📊 Performance Test Results:" -ForegroundColor Cyan
    Write-Host "   Test Duration: $([math]::Round($performanceTest.TestDuration, 2)) ms" -ForegroundColor White
    Write-Host "   CPU Load (Start): $($performanceTest.StartCPU)%" -ForegroundColor White
    Write-Host "   CPU Load (End): $($performanceTest.EndCPU)%" -ForegroundColor White
    
    Write-Host "`n3️⃣ Temperature Monitoring Test..." -ForegroundColor Yellow
    
    $tempMonitoring = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $tempResults = @{}
        
        # WMI温度センサー確認
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $tempList = @()
                foreach ($temp in $temps) {
                    $celsius = ($temp.CurrentTemperature - 2732) / 10
                    $tempList += "Zone $($temp.InstanceName): $celsius°C"
                }
                $tempResults.WMI_Temps = $tempList
            } else {
                $tempResults.WMI_Temps = "WMI temperature sensors not available"
            }
        } catch {
            $tempResults.WMI_Temps = "WMI temperature access failed"
        }
        
        # システム稼働時間
        $os = Get-WmiObject Win32_OperatingSystem
        $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $uptime = (Get-Date) - $lastBoot
        $tempResults.Uptime = "$($uptime.Hours)時間 $($uptime.Minutes)分"
        $tempResults.LastBoot = $lastBoot
        
        return $tempResults
    }
    
    Write-Host "`n🌡️ Temperature Status:" -ForegroundColor Cyan
    if ($tempMonitoring.WMI_Temps -is [array]) {
        foreach ($temp in $tempMonitoring.WMI_Temps) {
            Write-Host "   $temp" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   $($tempMonitoring.WMI_Temps)" -ForegroundColor Gray
        Write-Host "   💡 Recommendation: Install HWiNFO64 for detailed temperature monitoring" -ForegroundColor Cyan
    }
    
    Write-Host "   System Uptime: $($tempMonitoring.Uptime)" -ForegroundColor White
    Write-Host "   Last Boot: $($tempMonitoring.LastBoot)" -ForegroundColor White
    
    Write-Host "`n4️⃣ Stress Test (Short Duration)..." -ForegroundColor Yellow
    
    $stressTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $stressResults = @{}
        
        Write-Host "   Starting 30-second stress test..."
        $startTime = Get-Date
        $startCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        # より重い負荷をかける（30秒間）
        $job = Start-Job -ScriptBlock {
            $endTime = (Get-Date).AddSeconds(30)
            while ((Get-Date) -lt $endTime) {
                1..1000 | ForEach-Object { 
                    [Math]::Sqrt($_) * [Math]::Sin($_) * [Math]::Cos($_) 
                } | Out-Null
            }
        }
        
        # ジョブ完了まで待機
        Wait-Job $job -Timeout 35 | Out-Null
        Remove-Job $job -Force
        
        $endTime = Get-Date
        $endCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        $stressResults.Duration = ($endTime - $startTime).TotalSeconds
        $stressResults.StartCPU = $startCPU
        $stressResults.EndCPU = $endCPU
        $stressResults.MaxCPU = $endCPU  # 簡易的な最大値
        
        return $stressResults
    }
    
    Write-Host "`n⚡ Stress Test Results:" -ForegroundColor Cyan
    Write-Host "   Test Duration: $([math]::Round($stressTest.Duration, 1)) seconds" -ForegroundColor White
    Write-Host "   CPU Load (Start): $($stressTest.StartCPU)%" -ForegroundColor White
    Write-Host "   CPU Load (End): $($stressTest.EndCPU)%" -ForegroundColor White
    Write-Host "   Max CPU Load: $($stressTest.MaxCPU)%" -ForegroundColor White
    
    # システムが予期しないシャットダウンしていないか確認
    Write-Host "`n5️⃣ Stability Check..." -ForegroundColor Yellow
    
    $stabilityCheck = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        # 最新の予期しないシャットダウンをチェック
        $latestShutdown = Get-EventLog -LogName System -Source "EventLog" -EntryType Error -Newest 1 | 
                         Where-Object { $_.EventID -eq 6008 }
        
        if ($latestShutdown) {
            return @{
                HasRecentShutdown = $true
                LastShutdown = $latestShutdown.TimeGenerated
                Message = $latestShutdown.Message
            }
        } else {
            return @{
                HasRecentShutdown = $false
                Message = "No recent unexpected shutdowns detected"
            }
        }
    }
    
    Write-Host "`n🔍 Stability Status:" -ForegroundColor Cyan
    if ($stabilityCheck.HasRecentShutdown) {
        Write-Host "   ⚠️  Last Unexpected Shutdown: $($stabilityCheck.LastShutdown)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ No Recent Unexpected Shutdowns" -ForegroundColor Green
    }
    
    # 総合評価
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "          VERIFICATION SUMMARY" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green
    
    $overallStatus = "GOOD"
    
    if ($powerConfig.ActivePlan -match "Thermal Protection Plan") {
        Write-Host "✅ Power Plan: Thermal Protection Plan ACTIVE" -ForegroundColor Green
    } else {
        Write-Host "❌ Power Plan: NOT using Thermal Protection Plan" -ForegroundColor Red
        $overallStatus = "NEEDS ATTENTION"
    }
    
    if ($powerConfig.CPUMaxAC -eq 85 -and $powerConfig.CPUMaxDC -eq 80) {
        Write-Host "✅ CPU Limits: Correctly configured (85%/80%)" -ForegroundColor Green
    } else {
        Write-Host "❌ CPU Limits: Not properly configured" -ForegroundColor Red
        $overallStatus = "NEEDS ATTENTION"
    }
    
    if ($powerConfig.TurboAC -eq 0 -and $powerConfig.TurboDC -eq 0) {
        Write-Host "✅ Turbo Boost: Properly disabled for thermal protection" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Turbo Boost: Still enabled (thermal risk)" -ForegroundColor Yellow
        $overallStatus = "CAUTION"
    }
    
    if (-not $stabilityCheck.HasRecentShutdown) {
        Write-Host "✅ System Stability: No recent unexpected shutdowns" -ForegroundColor Green
    } else {
        Write-Host "⚠️  System Stability: Recent shutdown detected" -ForegroundColor Yellow
    }
    
    Write-Host "`nOVERALL STATUS: $overallStatus" -ForegroundColor $(
        switch ($overallStatus) {
            "GOOD" { "Green" }
            "CAUTION" { "Yellow" }
            "NEEDS ATTENTION" { "Red" }
        }
    )
    
    Write-Host "`n📝 RECOMMENDATIONS:" -ForegroundColor Cyan
    Write-Host "1. Monitor system for 24-48 hours for shutdown reduction" -ForegroundColor White
    Write-Host "2. Install HWiNFO64 for real-time temperature monitoring" -ForegroundColor White
    Write-Host "3. Clean laptop fans and heat sinks for better cooling" -ForegroundColor White
    Write-Host "4. If shutdowns persist, consider thermal paste replacement" -ForegroundColor White
    
} catch {
    Write-Host "❌ Verification failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nVerification complete. Press Enter to continue..." -ForegroundColor Gray
Read-Host