# 包括的システム評価とベストプラクティス確認スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  COMPREHENSIVE SYSTEM EVALUATION" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Target: $targetPC (AMD Ryzen 9 6900HX System)" -ForegroundColor Cyan

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n🔍 Phase 1: System Stability & Performance Analysis..." -ForegroundColor Yellow
    
    $systemAnalysis = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $analysis = @{}
        
        # === システム安定性評価 ===
        
        # 予期しないシャットダウン履歴
        try {
            $shutdownEvents = Get-EventLog -LogName System -Source "EventLog" -EntryType Error -Newest 10 | 
                             Where-Object { $_.EventID -eq 6008 }
            $analysis.UnexpectedShutdowns = $shutdownEvents.Count
            $analysis.LastShutdown = if ($shutdownEvents) { $shutdownEvents[0].TimeGenerated } else { "None" }
        } catch {
            $analysis.UnexpectedShutdowns = "Could not check"
        }
        
        # システムエラー確認
        try {
            $systemErrors = Get-EventLog -LogName System -EntryType Error -Newest 20
            $analysis.RecentSystemErrors = $systemErrors.Count
        } catch {
            $analysis.RecentSystemErrors = "Could not check"
        }
        
        # アプリケーションエラー確認
        try {
            $appErrors = Get-EventLog -LogName Application -EntryType Error -Newest 20
            $analysis.RecentAppErrors = $appErrors.Count
        } catch {
            $analysis.RecentAppErrors = "Could not check"
        }
        
        # === 現在のシステム状態 ===
        
        # CPU使用率
        $cpu = Get-WmiObject Win32_Processor
        $analysis.CPUUsage = $cpu.LoadPercentage
        
        # メモリ使用状況
        $os = Get-WmiObject Win32_OperatingSystem
        $totalMem = $os.TotalVisibleMemorySize / 1MB
        $freeMem = $os.FreePhysicalMemory / 1MB
        $usedMem = $totalMem - $freeMem
        $analysis.MemoryUsagePercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
        $analysis.MemoryUsedGB = [math]::Round($usedMem, 2)
        $analysis.MemoryTotalGB = [math]::Round($totalMem, 2)
        
        # ページファイル使用状況
        $pageFile = Get-WmiObject Win32_PageFileUsage
        if ($pageFile) {
            $analysis.PageFileUsagePercent = [math]::Round(($pageFile.CurrentUsage / $pageFile.AllocatedBaseSize) * 100, 1)
        } else {
            $analysis.PageFileUsagePercent = "Not configured"
        }
        
        # === 電源とCPU管理 ===
        
        # アクティブ電源プラン
        $activePlan = powercfg /getactivescheme
        $analysis.ActivePowerPlan = $activePlan
        
        # 高精度イベントタイマー (HPET) 状態
        try {
            $hpet = bcdedit /enum | Select-String "useplatformclock"
            $analysis.HPETStatus = if ($hpet) { $hpet.ToString() } else { "Default" }
        } catch {
            $analysis.HPETStatus = "Could not check"
        }
        
        # === サービス状態確認 ===
        
        # 重要なサービス状態
        $criticalServices = @("WinRM", "Themes", "AudioEndpointBuilder", "Audiosrv", "EventLog", "PlugPlay")
        $analysis.ServiceStatus = @{}
        foreach ($service in $criticalServices) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                $analysis.ServiceStatus[$service] = if ($svc) { $svc.Status } else { "Not found" }
            } catch {
                $analysis.ServiceStatus[$service] = "Error"
            }
        }
        
        # === 起動プログラム確認 ===
        
        # 起動時自動実行プログラム数
        try {
            $startupItems = Get-WmiObject Win32_StartupCommand
            $analysis.StartupProgramCount = $startupItems.Count
        } catch {
            $analysis.StartupProgramCount = "Could not check"
        }
        
        # === ディスク使用状況 ===
        
        # システムドライブ使用状況
        $systemDrive = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
        if ($systemDrive) {
            $analysis.SystemDriveUsagePercent = [math]::Round((($systemDrive.Size - $systemDrive.FreeSpace) / $systemDrive.Size) * 100, 1)
            $analysis.SystemDriveFreeGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
        }
        
        return $analysis
    }
    
    # Phase 1 結果表示
    Write-Host "`n📊 System Stability Analysis:" -ForegroundColor Cyan
    Write-Host "  Unexpected Shutdowns (recent): $($systemAnalysis.UnexpectedShutdowns)" -ForegroundColor $(if ($systemAnalysis.UnexpectedShutdowns -eq 0) { "Green" } else { "Red" })
    Write-Host "  Last Shutdown: $($systemAnalysis.LastShutdown)" -ForegroundColor White
    Write-Host "  Recent System Errors: $($systemAnalysis.RecentSystemErrors)" -ForegroundColor $(if ($systemAnalysis.RecentSystemErrors -lt 5) { "Green" } else { "Yellow" })
    Write-Host "  Recent App Errors: $($systemAnalysis.RecentAppErrors)" -ForegroundColor $(if ($systemAnalysis.RecentAppErrors -lt 10) { "Green" } else { "Yellow" })
    
    Write-Host "`n💻 Current System Performance:" -ForegroundColor Cyan
    Write-Host "  CPU Usage: $($systemAnalysis.CPUUsage)%" -ForegroundColor $(if ($systemAnalysis.CPUUsage -lt 50) { "Green" } elseif ($systemAnalysis.CPUUsage -lt 80) { "Yellow" } else { "Red" })
    Write-Host "  Memory Usage: $($systemAnalysis.MemoryUsagePercent)% ($($systemAnalysis.MemoryUsedGB)GB / $($systemAnalysis.MemoryTotalGB)GB)" -ForegroundColor $(if ($systemAnalysis.MemoryUsagePercent -lt 70) { "Green" } elseif ($systemAnalysis.MemoryUsagePercent -lt 85) { "Yellow" } else { "Red" })
    Write-Host "  Page File Usage: $($systemAnalysis.PageFileUsagePercent)%" -ForegroundColor White
    Write-Host "  System Drive Usage: $($systemAnalysis.SystemDriveUsagePercent)% (Free: $($systemAnalysis.SystemDriveFreeGB)GB)" -ForegroundColor $(if ($systemAnalysis.SystemDriveUsagePercent -lt 80) { "Green" } elseif ($systemAnalysis.SystemDriveUsagePercent -lt 90) { "Yellow" } else { "Red" })
    
    Write-Host "`n⚡ Power Management:" -ForegroundColor Cyan
    Write-Host "  $($systemAnalysis.ActivePowerPlan)" -ForegroundColor Green
    
    Write-Host "`n🔧 Critical Services Status:" -ForegroundColor Cyan
    foreach ($service in $systemAnalysis.ServiceStatus.Keys) {
        $status = $systemAnalysis.ServiceStatus[$service]
        $color = if ($status -eq "Running") { "Green" } elseif ($status -eq "Stopped") { "Red" } else { "Yellow" }
        Write-Host "  $service`: $status" -ForegroundColor $color
    }
    
    Write-Host "`n🚀 Startup Programs: $($systemAnalysis.StartupProgramCount)" -ForegroundColor $(if ($systemAnalysis.StartupProgramCount -lt 20) { "Green" } elseif ($systemAnalysis.StartupProgramCount -lt 40) { "Yellow" } else { "Red" })
    
} catch {
    Write-Host "❌ System analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Phase 2: 詳細設定確認
try {
    Write-Host "`n🔍 Phase 2: Advanced Configuration Analysis..." -ForegroundColor Yellow
    
    $advancedConfig = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $config = @{}
        
        # === 電源管理詳細設定 ===
        
        # USB選択的サスペンド
        try {
            $usbSuspend = powercfg /query SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND
            $config.USBSelectiveSuspend = $usbSuspend
        } catch {
            $config.USBSelectiveSuspend = "Could not check"
        }
        
        # PCI Express電源管理
        try {
            $pciePower = powercfg /query SCHEME_CURRENT SUB_PCIEXPRESS ASPM
            $config.PCIePowerManagement = $pciePower
        } catch {
            $config.PCIePowerManagement = "Could not check"
        }
        
        # === Windows Update設定 ===
        
        # Windows Update自動更新設定
        try {
            $wuSetting = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name AUOptions -ErrorAction SilentlyContinue
            $config.WindowsUpdateSetting = if ($wuSetting) { $wuSetting.AUOptions } else { "Default" }
        } catch {
            $config.WindowsUpdateSetting = "Could not check"
        }
        
        # === グラフィックス設定 ===
        
        # Windows Graphics設定
        try {
            $graphicsSettings = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue
            $config.GraphicsDriverSettings = "Available"
        } catch {
            $config.GraphicsDriverSettings = "Could not check"
        }
        
        # === ネットワーク最適化 ===
        
        # TCP Chimney Offload
        try {
            $tcpChimney = netsh int tcp show global | Select-String "Chimney Offload"
            $config.TCPChimneyOffload = if ($tcpChimney) { $tcpChimney.ToString().Trim() } else { "Default" }
        } catch {
            $config.TCPChimneyOffload = "Could not check"
        }
        
        # === セキュリティ設定 ===
        
        # Windows Defender状態
        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($defenderStatus) {
                $config.DefenderRealTimeProtection = $defenderStatus.RealTimeProtectionEnabled
                $config.DefenderLastQuickScan = $defenderStatus.QuickScanAge
            } else {
                $config.DefenderRealTimeProtection = "Could not check"
            }
        } catch {
            $config.DefenderRealTimeProtection = "Could not check"
        }
        
        # ファイアウォール状態
        try {
            $firewallProfiles = Get-NetFirewallProfile
            $config.FirewallStatus = @{}
            foreach ($profile in $firewallProfiles) {
                $config.FirewallStatus[$profile.Name] = $profile.Enabled
            }
        } catch {
            $config.FirewallStatus = "Could not check"
        }
        
        # === システム最適化設定 ===
        
        # 視覚効果設定
        try {
            $visualEffects = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -ErrorAction SilentlyContinue
            $config.VisualEffects = if ($visualEffects) { $visualEffects.VisualFXSetting } else { "Default" }
        } catch {
            $config.VisualEffects = "Could not check"
        }
        
        return $config
    }
    
    # Phase 2 結果表示
    Write-Host "`n🔋 Power Management Details:" -ForegroundColor Cyan
    if ($advancedConfig.USBSelectiveSuspend -match "0x00000001") {
        Write-Host "  USB Selective Suspend: Enabled" -ForegroundColor Green
    } else {
        Write-Host "  USB Selective Suspend: Status unclear" -ForegroundColor Yellow
    }
    
    Write-Host "`n🛡️ Security Configuration:" -ForegroundColor Cyan
    Write-Host "  Windows Defender Real-time: $($advancedConfig.DefenderRealTimeProtection)" -ForegroundColor $(if ($advancedConfig.DefenderRealTimeProtection -eq $true) { "Green" } else { "Yellow" })
    
    if ($advancedConfig.FirewallStatus -is [hashtable]) {
        foreach ($profile in $advancedConfig.FirewallStatus.Keys) {
            $status = $advancedConfig.FirewallStatus[$profile]
            Write-Host "  Firewall ($profile): $status" -ForegroundColor $(if ($status) { "Green" } else { "Red" })
        }
    }
    
} catch {
    Write-Host "❌ Advanced configuration analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Phase 3: ベストプラクティス評価と改善提案
Write-Host "`n🎯 Phase 3: Best Practices Evaluation & Recommendations..." -ForegroundColor Yellow

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "            SYSTEM OPTIMIZATION ASSESSMENT" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

# 評価結果とスコア算出
$overallScore = 0
$maxScore = 0
$recommendations = @()

# 安定性評価
Write-Host "`n🔍 STABILITY ASSESSMENT:" -ForegroundColor Cyan
if ($systemAnalysis.UnexpectedShutdowns -eq 0) {
    Write-Host "  ✅ No unexpected shutdowns - EXCELLENT" -ForegroundColor Green
    $overallScore += 20
} elseif ($systemAnalysis.UnexpectedShutdowns -lt 5) {
    Write-Host "  ⚠️  Few unexpected shutdowns - GOOD" -ForegroundColor Yellow
    $overallScore += 15
    $recommendations += "Monitor system for thermal issues"
} else {
    Write-Host "  ❌ Multiple unexpected shutdowns - NEEDS ATTENTION" -ForegroundColor Red
    $overallScore += 5
    $recommendations += "Investigate recurring shutdown causes"
}
$maxScore += 20

# パフォーマンス評価
Write-Host "`n⚡ PERFORMANCE ASSESSMENT:" -ForegroundColor Cyan
if ($systemAnalysis.MemoryUsagePercent -lt 70) {
    Write-Host "  ✅ Memory usage optimal - EXCELLENT" -ForegroundColor Green
    $overallScore += 15
} elseif ($systemAnalysis.MemoryUsagePercent -lt 85) {
    Write-Host "  ⚠️  Memory usage moderate - GOOD" -ForegroundColor Yellow
    $overallScore += 10
} else {
    Write-Host "  ❌ Memory usage high - NEEDS OPTIMIZATION" -ForegroundColor Red
    $overallScore += 5
    $recommendations += "Close unnecessary applications or add more RAM"
}
$maxScore += 15

if ($systemAnalysis.SystemDriveUsagePercent -lt 80) {
    Write-Host "  ✅ Disk usage healthy - EXCELLENT" -ForegroundColor Green
    $overallScore += 10
} elseif ($systemAnalysis.SystemDriveUsagePercent -lt 90) {
    Write-Host "  ⚠️  Disk usage moderate - GOOD" -ForegroundColor Yellow
    $overallScore += 7
    $recommendations += "Consider disk cleanup or additional storage"
} else {
    Write-Host "  ❌ Disk usage critical - IMMEDIATE ACTION NEEDED" -ForegroundColor Red
    $overallScore += 3
    $recommendations += "Free up disk space immediately"
}
$maxScore += 10

# 電源管理評価
Write-Host "`n🔋 POWER MANAGEMENT ASSESSMENT:" -ForegroundColor Cyan
if ($systemAnalysis.ActivePowerPlan -match "Thermal Protection Plan") {
    Write-Host "  ✅ Thermal Protection Plan active - EXCELLENT" -ForegroundColor Green
    $overallScore += 20
} else {
    Write-Host "  ❌ Thermal Protection Plan not active - CRITICAL" -ForegroundColor Red
    $overallScore += 5
    $recommendations += "Activate Thermal Protection Plan immediately"
}
$maxScore += 20

# 起動最適化評価
Write-Host "`n🚀 STARTUP OPTIMIZATION:" -ForegroundColor Cyan
if ($systemAnalysis.StartupProgramCount -lt 20) {
    Write-Host "  ✅ Startup programs optimized - EXCELLENT" -ForegroundColor Green
    $overallScore += 10
} elseif ($systemAnalysis.StartupProgramCount -lt 40) {
    Write-Host "  ⚠️  Moderate startup programs - GOOD" -ForegroundColor Yellow
    $overallScore += 7
    $recommendations += "Review and disable unnecessary startup programs"
} else {
    Write-Host "  ❌ Too many startup programs - NEEDS OPTIMIZATION" -ForegroundColor Red
    $overallScore += 3
    $recommendations += "Disable non-essential startup programs"
}
$maxScore += 10

# セキュリティ評価
Write-Host "`n🛡️ SECURITY ASSESSMENT:" -ForegroundColor Cyan
if ($advancedConfig.DefenderRealTimeProtection -eq $true) {
    Write-Host "  ✅ Real-time protection enabled - EXCELLENT" -ForegroundColor Green
    $overallScore += 15
} else {
    Write-Host "  ❌ Real-time protection status unclear - VERIFY" -ForegroundColor Yellow
    $overallScore += 10
    $recommendations += "Verify Windows Defender real-time protection is enabled"
}
$maxScore += 15

# 総合スコア算出
$scorePercentage = [math]::Round(($overallScore / $maxScore) * 100, 1)

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "              OVERALL SYSTEM SCORE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

$scoreColor = if ($scorePercentage -ge 90) { "Green" } elseif ($scorePercentage -ge 75) { "Yellow" } else { "Red" }
$scoreRating = if ($scorePercentage -ge 90) { "EXCELLENT" } elseif ($scorePercentage -ge 75) { "GOOD" } elseif ($scorePercentage -ge 60) { "FAIR" } else { "NEEDS IMPROVEMENT" }

Write-Host "`n🎯 SYSTEM SCORE: $scorePercentage% - $scoreRating" -ForegroundColor $scoreColor
Write-Host "   ($overallScore / $maxScore points)" -ForegroundColor White

# 改善提案
if ($recommendations.Count -gt 0) {
    Write-Host "`n📋 RECOMMENDED IMPROVEMENTS:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $recommendations.Count; $i++) {
        Write-Host "   $($i + 1). $($recommendations[$i])" -ForegroundColor White
    }
} else {
    Write-Host "`n🎉 NO IMMEDIATE IMPROVEMENTS NEEDED!" -ForegroundColor Green
    Write-Host "   System is well-optimized and stable" -ForegroundColor Green
}

# 追加のベストプラクティス提案
Write-Host "`n🏆 ADDITIONAL BEST PRACTICES:" -ForegroundColor Cyan
Write-Host "   • Regular Windows Updates (monthly)" -ForegroundColor White
Write-Host "   • Disk cleanup and defragmentation (quarterly)" -ForegroundColor White
Write-Host "   • Temperature monitoring (install HWiNFO64)" -ForegroundColor White
Write-Host "   • Regular backup of important data" -ForegroundColor White
Write-Host "   • Annual thermal paste replacement for high-performance CPUs" -ForegroundColor White

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "          SYSTEM EVALUATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue"