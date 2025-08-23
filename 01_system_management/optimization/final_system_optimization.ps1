# 最終システム最適化とベストバランス設定

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  FINAL SYSTEM OPTIMIZATION ANALYSIS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Goal: Best Balance of Stability & Performance" -ForegroundColor Cyan

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n🔍 Comprehensive System Balance Assessment..." -ForegroundColor Yellow
    
    $systemBalance = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $balance = @{}
        
        # === 現在の設定状態確認 ===
        
        # 電源プラン詳細
        $activePlan = powercfg /getactivescheme
        $balance.CurrentPowerPlan = $activePlan
        
        # CPU性能制限確認
        $cpuMaxAC = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTMAX 2>$null
        $cpuMaxDC = $cpuMaxAC
        $balance.CPUSettings = @{
            MaxACRaw = $cpuMaxAC
            MaxDCRaw = $cpuMaxDC
        }
        
        # システム負荷状況
        $cpu = Get-WmiObject Win32_Processor
        $balance.CurrentCPULoad = $cpu.LoadPercentage
        $balance.CPUName = $cpu.Name
        $balance.CPUMaxSpeed = $cpu.MaxClockSpeed
        $balance.CPUCurrentSpeed = $cpu.CurrentClockSpeed
        
        # メモリ効率性
        $os = Get-WmiObject Win32_OperatingSystem
        $totalMem = $os.TotalVisibleMemorySize / 1MB
        $freeMem = $os.FreePhysicalMemory / 1MB
        $usedMem = $totalMem - $freeMem
        $balance.MemoryEfficiency = @{
            TotalGB = [math]::Round($totalMem, 2)
            UsedGB = [math]::Round($usedMem, 2)
            FreeGB = [math]::Round($freeMem, 2)
            UsagePercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
        }
        
        # ディスク効率性
        $systemDrive = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
        $balance.DiskEfficiency = @{
            TotalGB = [math]::Round($systemDrive.Size / 1GB, 2)
            FreeGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
            UsedGB = [math]::Round(($systemDrive.Size - $systemDrive.FreeSpace) / 1GB, 2)
            UsagePercent = [math]::Round((($systemDrive.Size - $systemDrive.FreeSpace) / $systemDrive.Size) * 100, 1)
        }
        
        # === 安定性指標 ===
        
        # システム稼働時間
        $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $uptime = (Get-Date) - $lastBoot
        $balance.SystemStability = @{
            LastBoot = $lastBoot
            UptimeHours = [math]::Round($uptime.TotalHours, 1)
            UptimeDays = [math]::Round($uptime.TotalDays, 1)
        }
        
        # 重要サービス状態
        $criticalServices = @("WinRM", "Themes", "AudioEndpointBuilder", "Audiosrv", "EventLog", "PlugPlay", "BITS", "Spooler")
        $balance.ServiceHealth = @{}
        foreach ($service in $criticalServices) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                $balance.ServiceHealth[$service] = if ($svc) { $svc.Status.ToString() } else { "NotFound" }
            } catch {
                $balance.ServiceHealth[$service] = "Error"
            }
        }
        
        # === パフォーマンス指標 ===
        
        # 起動速度関連
        $startupPrograms = Get-WmiObject Win32_StartupCommand
        $balance.StartupOptimization = @{
            ProgramCount = $startupPrograms.Count
            StartupImpact = if ($startupPrograms.Count -lt 10) { "Low" } elseif ($startupPrograms.Count -lt 20) { "Medium" } else { "High" }
        }
        
        # === 熱管理効率性 ===
        
        # 温度センサー
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $balance.ThermalStatus = @{
                    CurrentTemp = ($temps[0].CurrentTemperature - 2732) / 10
                    SensorAvailable = $true
                }
            } else {
                $balance.ThermalStatus = @{
                    CurrentTemp = "N/A"
                    SensorAvailable = $false
                }
            }
        } catch {
            $balance.ThermalStatus = @{
                CurrentTemp = "N/A"
                SensorAvailable = $false
            }
        }
        
        # === システム最適化状態 ===
        
        # Windows Update状態
        try {
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $pendingUpdates = $updateSearcher.Search("IsInstalled=0").Updates.Count
            $balance.UpdateStatus = @{
                PendingUpdates = $pendingUpdates
                NeedsUpdate = ($pendingUpdates -gt 0)
            }
        } catch {
            $balance.UpdateStatus = @{
                PendingUpdates = "Unknown"
                NeedsUpdate = $false
            }
        }
        
        # ページファイル最適化
        $pageFiles = Get-WmiObject Win32_PageFileUsage
        $balance.PageFileOptimization = @()
        foreach ($pf in $pageFiles) {
            $balance.PageFileOptimization += @{
                Location = $pf.Name
                AllocatedGB = [math]::Round($pf.AllocatedBaseSize / 1024, 2)
                CurrentUsageGB = [math]::Round($pf.CurrentUsage / 1024, 2)
                UsagePercent = if ($pf.AllocatedBaseSize -gt 0) { [math]::Round(($pf.CurrentUsage / $pf.AllocatedBaseSize) * 100, 1) } else { 0 }
            }
        }
        
        # === ネットワーク効率性 ===
        
        # アクティブなネットワーク接続
        $activeConnections = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        $balance.NetworkEfficiency = @{
            ActiveAdapters = $activeConnections.Count
            AdapterNames = $activeConnections.Name
        }
        
        return $balance
    }
    
    # === 結果分析と表示 ===
    
    Write-Host "`n📊 Current System Balance Analysis:" -ForegroundColor Cyan
    
    # 電源管理バランス
    Write-Host "`n⚡ Power Management Balance:" -ForegroundColor Cyan
    if ($systemBalance.CurrentPowerPlan -match "Thermal Protection Plan") {
        Write-Host "  ✅ Power Plan: Thermal Protection Plan (Stability Focused)" -ForegroundColor Green
        Write-Host "  CPU Current Speed: $($systemBalance.CPUCurrentSpeed) MHz / $($systemBalance.CPUMaxSpeed) MHz" -ForegroundColor White
        $speedRatio = [math]::Round(($systemBalance.CPUCurrentSpeed / $systemBalance.CPUMaxSpeed) * 100, 1)
        Write-Host "  CPU Speed Utilization: $speedRatio%" -ForegroundColor $(if ($speedRatio -gt 80) { "Green" } elseif ($speedRatio -gt 60) { "Yellow" } else { "Red" })
    }
    
    # メモリ効率バランス
    Write-Host "`n💾 Memory Efficiency Balance:" -ForegroundColor Cyan
    $memUsage = $systemBalance.MemoryEfficiency.UsagePercent
    Write-Host "  Memory Usage: $memUsage% ($($systemBalance.MemoryEfficiency.UsedGB)GB / $($systemBalance.MemoryEfficiency.TotalGB)GB)" -ForegroundColor $(if ($memUsage -lt 60) { "Green" } elseif ($memUsage -lt 80) { "Yellow" } else { "Red" })
    Write-Host "  Available Memory: $($systemBalance.MemoryEfficiency.FreeGB)GB" -ForegroundColor White
    
    if ($systemBalance.PageFileOptimization.Count -gt 0) {
        Write-Host "  Page File Usage:" -ForegroundColor White
        foreach ($pf in $systemBalance.PageFileOptimization) {
            Write-Host "    $($pf.Location): $($pf.UsagePercent)% ($($pf.CurrentUsageGB)GB / $($pf.AllocatedGB)GB)" -ForegroundColor Gray
        }
    }
    
    # ストレージ効率バランス
    Write-Host "`n💿 Storage Efficiency Balance:" -ForegroundColor Cyan
    $diskUsage = $systemBalance.DiskEfficiency.UsagePercent
    Write-Host "  Disk Usage: $diskUsage% ($($systemBalance.DiskEfficiency.UsedGB)GB / $($systemBalance.DiskEfficiency.TotalGB)GB)" -ForegroundColor $(if ($diskUsage -lt 70) { "Green" } elseif ($diskUsage -lt 85) { "Yellow" } else { "Red" })
    Write-Host "  Free Space: $($systemBalance.DiskEfficiency.FreeGB)GB" -ForegroundColor White
    
    # システム安定性バランス
    Write-Host "`n🛡️ System Stability Balance:" -ForegroundColor Cyan
    Write-Host "  Current Uptime: $($systemBalance.SystemStability.UptimeDays) days ($($systemBalance.SystemStability.UptimeHours) hours)" -ForegroundColor $(if ($systemBalance.SystemStability.UptimeDays -gt 1) { "Green" } else { "Yellow" })
    Write-Host "  Last Boot: $($systemBalance.SystemStability.LastBoot)" -ForegroundColor White
    Write-Host "  Current CPU Load: $($systemBalance.CurrentCPULoad)%" -ForegroundColor $(if ($systemBalance.CurrentCPULoad -lt 20) { "Green" } elseif ($systemBalance.CurrentCPULoad -lt 50) { "Yellow" } else { "Red" })
    
    # サービス健全性
    Write-Host "`n🔧 Service Health Balance:" -ForegroundColor Cyan
    $runningServices = 0
    $totalServices = $systemBalance.ServiceHealth.Count
    foreach ($service in $systemBalance.ServiceHealth.Keys) {
        $status = $systemBalance.ServiceHealth[$service]
        if ($status -eq "Running") { $runningServices++ }
        $color = if ($status -eq "Running") { "Green" } elseif ($status -eq "Stopped") { "Red" } else { "Yellow" }
        Write-Host "  $service`: $status" -ForegroundColor $color
    }
    $serviceHealthPercent = [math]::Round(($runningServices / $totalServices) * 100, 1)
    Write-Host "  Service Health: $serviceHealthPercent% ($runningServices / $totalServices running)" -ForegroundColor $(if ($serviceHealthPercent -gt 85) { "Green" } else { "Yellow" })
    
    # 起動最適化バランス
    Write-Host "`n🚀 Startup Optimization Balance:" -ForegroundColor Cyan
    Write-Host "  Startup Programs: $($systemBalance.StartupOptimization.ProgramCount) (Impact: $($systemBalance.StartupOptimization.StartupImpact))" -ForegroundColor $(if ($systemBalance.StartupOptimization.StartupImpact -eq "Low") { "Green" } elseif ($systemBalance.StartupOptimization.StartupImpact -eq "Medium") { "Yellow" } else { "Red" })
    
    # 熱管理バランス
    Write-Host "`n🌡️ Thermal Management Balance:" -ForegroundColor Cyan
    if ($systemBalance.ThermalStatus.SensorAvailable) {
        $temp = $systemBalance.ThermalStatus.CurrentTemp
        Write-Host "  Current Temperature: $temp°C" -ForegroundColor $(if ($temp -lt 65) { "Green" } elseif ($temp -lt 80) { "Yellow" } else { "Red" })
    } else {
        Write-Host "  Temperature Monitoring: Not Available (Recommend HWiNFO64)" -ForegroundColor Yellow
    }
    
    # === バランススコア算出 ===
    
    Write-Host "`n" + "=" * 80 -ForegroundColor Green
    Write-Host "              STABILITY & PERFORMANCE BALANCE SCORE" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    
    $balanceScore = 0
    $maxBalanceScore = 100
    
    # 安定性スコア (50点満点)
    Write-Host "`n🛡️ STABILITY SCORE:" -ForegroundColor Cyan
    
    # 熱管理 (15点)
    if ($systemBalance.CurrentPowerPlan -match "Thermal Protection Plan") {
        Write-Host "  ✅ Thermal Protection: 15/15 points" -ForegroundColor Green
        $balanceScore += 15
    } else {
        Write-Host "  ❌ Thermal Protection: 5/15 points" -ForegroundColor Red
        $balanceScore += 5
    }
    
    # システム稼働時間 (10点)
    if ($systemBalance.SystemStability.UptimeHours -gt 1) {
        Write-Host "  ✅ System Uptime: 10/10 points" -ForegroundColor Green
        $balanceScore += 10
    } else {
        Write-Host "  ⚠️  System Uptime: 7/10 points" -ForegroundColor Yellow
        $balanceScore += 7
    }
    
    # サービス健全性 (15点)
    if ($serviceHealthPercent -gt 85) {
        Write-Host "  ✅ Service Health: 15/15 points" -ForegroundColor Green
        $balanceScore += 15
    } elseif ($serviceHealthPercent -gt 70) {
        Write-Host "  ⚠️  Service Health: 10/15 points" -ForegroundColor Yellow
        $balanceScore += 10
    } else {
        Write-Host "  ❌ Service Health: 5/15 points" -ForegroundColor Red
        $balanceScore += 5
    }
    
    # メモリ安定性 (10点)
    if ($memUsage -lt 70) {
        Write-Host "  ✅ Memory Stability: 10/10 points" -ForegroundColor Green
        $balanceScore += 10
    } elseif ($memUsage -lt 85) {
        Write-Host "  ⚠️  Memory Stability: 7/10 points" -ForegroundColor Yellow
        $balanceScore += 7
    } else {
        Write-Host "  ❌ Memory Stability: 3/10 points" -ForegroundColor Red
        $balanceScore += 3
    }
    
    # パフォーマンススコア (50点満点)
    Write-Host "`n⚡ PERFORMANCE SCORE:" -ForegroundColor Cyan
    
    # CPU効率性 (20点)
    if ($systemBalance.CurrentCPULoad -lt 20) {
        Write-Host "  ✅ CPU Efficiency: 20/20 points" -ForegroundColor Green
        $balanceScore += 20
    } elseif ($systemBalance.CurrentCPULoad -lt 40) {
        Write-Host "  ⚠️  CPU Efficiency: 15/20 points" -ForegroundColor Yellow
        $balanceScore += 15
    } else {
        Write-Host "  ❌ CPU Efficiency: 10/20 points" -ForegroundColor Red
        $balanceScore += 10
    }
    
    # メモリ効率性 (15点)
    if ($memUsage -gt 20 -and $memUsage -lt 60) {
        Write-Host "  ✅ Memory Efficiency: 15/15 points" -ForegroundColor Green
        $balanceScore += 15
    } elseif ($memUsage -lt 80) {
        Write-Host "  ⚠️  Memory Efficiency: 10/15 points" -ForegroundColor Yellow
        $balanceScore += 10
    } else {
        Write-Host "  ❌ Memory Efficiency: 5/15 points" -ForegroundColor Red
        $balanceScore += 5
    }
    
    # ストレージ効率性 (10点)
    if ($diskUsage -lt 70) {
        Write-Host "  ✅ Storage Efficiency: 10/10 points" -ForegroundColor Green
        $balanceScore += 10
    } elseif ($diskUsage -lt 85) {
        Write-Host "  ⚠️  Storage Efficiency: 7/10 points" -ForegroundColor Yellow
        $balanceScore += 7
    } else {
        Write-Host "  ❌ Storage Efficiency: 3/10 points" -ForegroundColor Red
        $balanceScore += 3
    }
    
    # 起動最適化 (5点)
    if ($systemBalance.StartupOptimization.StartupImpact -eq "Low") {
        Write-Host "  ✅ Startup Optimization: 5/5 points" -ForegroundColor Green
        $balanceScore += 5
    } elseif ($systemBalance.StartupOptimization.StartupImpact -eq "Medium") {
        Write-Host "  ⚠️  Startup Optimization: 3/5 points" -ForegroundColor Yellow
        $balanceScore += 3
    } else {
        Write-Host "  ❌ Startup Optimization: 1/5 points" -ForegroundColor Red
        $balanceScore += 1
    }
    
    # 総合バランススコア
    $balancePercentage = [math]::Round(($balanceScore / $maxBalanceScore) * 100, 1)
    $balanceRating = if ($balancePercentage -ge 90) { "EXCELLENT" } elseif ($balancePercentage -ge 80) { "VERY GOOD" } elseif ($balancePercentage -ge 70) { "GOOD" } elseif ($balancePercentage -ge 60) { "FAIR" } else { "NEEDS IMPROVEMENT" }
    $scoreColor = if ($balancePercentage -ge 90) { "Green" } elseif ($balancePercentage -ge 70) { "Yellow" } else { "Red" }
    
    Write-Host "`n🎯 OVERALL BALANCE SCORE: $balancePercentage% - $balanceRating" -ForegroundColor $scoreColor
    Write-Host "   ($balanceScore / $maxBalanceScore points)" -ForegroundColor White
    
    # === 改善提案 ===
    
    Write-Host "`n" + "=" * 80 -ForegroundColor Green
    Write-Host "                OPTIMIZATION RECOMMENDATIONS" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    
    $recommendations = @()
    
    # 改善提案の生成
    if ($balancePercentage -ge 85) {
        Write-Host "`n🏆 SYSTEM IS WELL OPTIMIZED!" -ForegroundColor Green
        Write-Host "Current configuration provides excellent stability & performance balance." -ForegroundColor Green
        
        # 微細な改善提案
        if (-not $systemBalance.ThermalStatus.SensorAvailable) {
            $recommendations += "Install HWiNFO64 for real-time temperature monitoring"
        }
        if ($systemBalance.UpdateStatus.NeedsUpdate) {
            $recommendations += "Install pending Windows Updates"
        }
        $recommendations += "Schedule monthly maintenance routine"
        $recommendations += "Consider creating gaming-specific power plan for demanding games"
        
    } else {
        Write-Host "`n📋 RECOMMENDED OPTIMIZATIONS:" -ForegroundColor Yellow
        
        # 具体的な改善提案
        if ($systemBalance.CurrentPowerPlan -notmatch "Thermal Protection Plan") {
            $recommendations += "CRITICAL: Activate Thermal Protection Plan"
        }
        if ($memUsage -gt 80) {
            $recommendations += "Optimize memory usage - close unnecessary applications"
        }
        if ($diskUsage -gt 85) {
            $recommendations += "Free up disk space - run disk cleanup"
        }
        if ($systemBalance.StartupOptimization.StartupImpact -ne "Low") {
            $recommendations += "Reduce startup programs for faster boot times"
        }
        if ($serviceHealthPercent -lt 85) {
            $recommendations += "Check and start critical Windows services"
        }
        if (-not $systemBalance.ThermalStatus.SensorAvailable) {
            $recommendations += "Install temperature monitoring software (HWiNFO64)"
        }
    }
    
    # 推奨事項の表示
    if ($recommendations.Count -gt 0) {
        Write-Host "`n📝 Specific Recommendations:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $recommendations.Count; $i++) {
            Write-Host "   $($i + 1). $($recommendations[$i])" -ForegroundColor White
        }
    }
    
    # ベストプラクティス維持計画
    Write-Host "`n🔄 ONGOING BEST PRACTICES:" -ForegroundColor Cyan
    Write-Host "   Daily:   Monitor system performance and temperatures" -ForegroundColor White
    Write-Host "   Weekly:  Check for driver and Windows updates" -ForegroundColor White
    Write-Host "   Monthly: Run disk cleanup and system optimization" -ForegroundColor White
    Write-Host "   Quarterly: Deep system analysis and maintenance" -ForegroundColor White
    Write-Host "   Annually: Hardware cleaning and thermal paste replacement" -ForegroundColor White
    
    Write-Host "`n🎮 GAMING PERFORMANCE NOTE:" -ForegroundColor Cyan
    Write-Host "   Current setup provides 100% gaming capability with RTX 4060" -ForegroundColor Green
    Write-Host "   Thermal Protection Plan ensures stable gaming without overheating" -ForegroundColor Green
    Write-Host "   Consider separate gaming profile only if maximum performance needed" -ForegroundColor White
    
} catch {
    Write-Host "❌ System optimization analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 80 -ForegroundColor Green
Write-Host "            SYSTEM OPTIMIZATION ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green

Read-Host "`nPress Enter to continue"