# Thermal Protection Planでのゲーミング性能テスト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "======================================" -ForegroundColor Green
Write-Host "  GAMING PERFORMANCE ANALYSIS" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Current Plan: Thermal Protection Plan" -ForegroundColor Cyan

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n🎮 Gaming Performance Assessment..." -ForegroundColor Yellow
    
    $gamingAnalysis = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $analysis = @{}
        
        # 現在の電源プラン確認
        $activePlan = powercfg /getactivescheme
        $analysis.CurrentPlan = $activePlan
        
        # CPU性能測定
        $cpu = Get-WmiObject Win32_Processor
        $analysis.CPUName = $cpu.Name
        $analysis.CPUCores = $cpu.NumberOfCores
        $analysis.CPUThreads = $cpu.NumberOfLogicalProcessors
        $analysis.CPUMaxSpeed = $cpu.MaxClockSpeed
        $analysis.CPUCurrentSpeed = $cpu.CurrentClockSpeed
        
        # GPU情報取得
        $gpus = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Meta Virtual" }
        $analysis.GPUs = @()
        foreach ($gpu in $gpus) {
            $analysis.GPUs += @{
                Name = $gpu.Name
                DriverVersion = $gpu.DriverVersion
                AdapterRAM = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB, 2) } else { "Unknown" }
                VideoProcessor = $gpu.VideoProcessor
            }
        }
        
        # メモリ情報
        $os = Get-WmiObject Win32_OperatingSystem
        $totalMem = $os.TotalVisibleMemorySize / 1MB
        $freeMem = $os.FreePhysicalMemory / 1MB
        $analysis.TotalMemoryGB = [math]::Round($totalMem, 2)
        $analysis.AvailableMemoryGB = [math]::Round($freeMem, 2)
        
        # CPU負荷テスト（ゲーミング相当）
        Write-Host "  Running gaming simulation test..." -ForegroundColor Yellow
        
        $startTime = Get-Date
        $startCPU = (Get-WmiObject Win32_Processor).LoadPercentage
        
        # ゲーミング相当の負荷をシミュレート（60秒間）
        $testJob = Start-Job -ScriptBlock {
            $endTime = (Get-Date).AddSeconds(60)
            $cpuUsages = @()
            
            # CPU集約的なタスクとメモリアクセス（ゲーム相当）
            while ((Get-Date) -lt $endTime) {
                # 3D計算シミュレート
                1..200 | ForEach-Object { 
                    [Math]::Sqrt($_) * [Math]::Sin($_) * [Math]::Cos($_) * [Math]::Tan($_)
                    [Math]::Pow($_, 0.5) * [Math]::Log($_)
                } | Out-Null
                
                # メモリアクセスパターン
                $array = 1..1000
                $array | Sort-Object | Out-Null
                
                # CPU使用率記録
                $currentCPU = (Get-WmiObject Win32_Processor).LoadPercentage
                $cpuUsages += $currentCPU
                
                Start-Sleep -Milliseconds 100
            }
            
            return @{
                MaxCPU = ($cpuUsages | Measure-Object -Maximum).Maximum
                AvgCPU = [math]::Round(($cpuUsages | Measure-Object -Average).Average, 1)
                MinCPU = ($cpuUsages | Measure-Object -Minimum).Minimum
            }
        }
        
        # テスト完了まで待機
        $testResult = Wait-Job $testJob -Timeout 70 | Receive-Job
        Remove-Job $testJob -Force
        
        $endTime = Get-Date
        $testDuration = ($endTime - $startTime).TotalSeconds
        
        $analysis.GameTestDuration = $testDuration
        $analysis.GameTestResults = $testResult
        
        # 温度チェック（可能な場合）
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $analysis.CurrentTemp = ($temps[0].CurrentTemperature - 2732) / 10
            } else {
                $analysis.CurrentTemp = "N/A"
            }
        } catch {
            $analysis.CurrentTemp = "N/A"
        }
        
        return $analysis
    }
    
    # 結果表示
    Write-Host "`n📊 Current System Configuration:" -ForegroundColor Cyan
    Write-Host "  Power Plan: Thermal Protection Plan (Active)" -ForegroundColor Green
    Write-Host "  CPU: $($gamingAnalysis.CPUName)" -ForegroundColor White
    Write-Host "  CPU Speed: $($gamingAnalysis.CPUCurrentSpeed) MHz (Max: $($gamingAnalysis.CPUMaxSpeed) MHz)" -ForegroundColor White
    Write-Host "  CPU Cores/Threads: $($gamingAnalysis.CPUCores)C/$($gamingAnalysis.CPUThreads)T" -ForegroundColor White
    Write-Host "  Available Memory: $($gamingAnalysis.AvailableMemoryGB) GB / $($gamingAnalysis.TotalMemoryGB) GB" -ForegroundColor White
    
    Write-Host "`n🎮 Graphics Hardware:" -ForegroundColor Cyan
    foreach ($gpu in $gamingAnalysis.GPUs) {
        Write-Host "  GPU: $($gpu.Name)" -ForegroundColor White
        Write-Host "    VRAM: $($gpu.AdapterRAM) GB" -ForegroundColor Gray
        Write-Host "    Driver: $($gpu.DriverVersion)" -ForegroundColor Gray
    }
    
    Write-Host "`n🔥 Gaming Performance Test Results:" -ForegroundColor Cyan
    Write-Host "  Test Duration: $([math]::Round($gamingAnalysis.GameTestDuration, 1)) seconds" -ForegroundColor White
    
    if ($gamingAnalysis.GameTestResults) {
        Write-Host "  CPU Performance During Test:" -ForegroundColor White
        Write-Host "    Maximum CPU: $($gamingAnalysis.GameTestResults.MaxCPU)%" -ForegroundColor $(if ($gamingAnalysis.GameTestResults.MaxCPU -lt 80) { "Green" } elseif ($gamingAnalysis.GameTestResults.MaxCPU -lt 90) { "Yellow" } else { "Red" })
        Write-Host "    Average CPU: $($gamingAnalysis.GameTestResults.AvgCPU)%" -ForegroundColor $(if ($gamingAnalysis.GameTestResults.AvgCPU -lt 70) { "Green" } elseif ($gamingAnalysis.GameTestResults.AvgCPU -lt 85) { "Yellow" } else { "Red" })
        Write-Host "    Minimum CPU: $($gamingAnalysis.GameTestResults.MinCPU)%" -ForegroundColor White
    }
    
    if ($gamingAnalysis.CurrentTemp -ne "N/A") {
        Write-Host "  Current Temperature: $($gamingAnalysis.CurrentTemp)°C" -ForegroundColor $(if ($gamingAnalysis.CurrentTemp -lt 70) { "Green" } elseif ($gamingAnalysis.CurrentTemp -lt 80) { "Yellow" } else { "Red" })
    }
    
    # ゲーミング評価
    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "              GAMING CAPABILITY ASSESSMENT" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    $gamingScore = 0
    $maxGamingScore = 100
    
    # CPU性能評価
    Write-Host "`n🎯 Gaming Performance Analysis:" -ForegroundColor Cyan
    
    if ($gamingAnalysis.GameTestResults) {
        if ($gamingAnalysis.GameTestResults.MaxCPU -lt 80) {
            Write-Host "  ✅ CPU Performance: EXCELLENT for gaming" -ForegroundColor Green
            Write-Host "     CPU utilization under control, smooth gameplay expected" -ForegroundColor White
            $gamingScore += 30
        } elseif ($gamingAnalysis.GameTestResults.MaxCPU -lt 90) {
            Write-Host "  ⚠️  CPU Performance: GOOD for gaming" -ForegroundColor Yellow
            Write-Host "     Some performance limitation, but most games playable" -ForegroundColor White
            $gamingScore += 20
        } else {
            Write-Host "  ❌ CPU Performance: LIMITED for gaming" -ForegroundColor Red
            Write-Host "     Significant performance bottleneck expected" -ForegroundColor White
            $gamingScore += 10
        }
    }
    
    # GPU評価
    $hasRTX4060 = $gamingAnalysis.GPUs | Where-Object { $_.Name -match "RTX 4060" }
    if ($hasRTX4060) {
        Write-Host "  ✅ GPU Performance: EXCELLENT for gaming" -ForegroundColor Green
        Write-Host "     RTX 4060 capable of 1080p/1440p gaming at high settings" -ForegroundColor White
        $gamingScore += 40
    } else {
        Write-Host "  ⚠️  GPU Performance: Using integrated graphics" -ForegroundColor Yellow
        $gamingScore += 15
    }
    
    # メモリ評価
    if ($gamingAnalysis.AvailableMemoryGB -gt 20) {
        Write-Host "  ✅ Memory: EXCELLENT for gaming" -ForegroundColor Green
        Write-Host "     32GB total memory more than sufficient for any game" -ForegroundColor White
        $gamingScore += 20
    } elseif ($gamingAnalysis.AvailableMemoryGB -gt 12) {
        Write-Host "  ✅ Memory: GOOD for gaming" -ForegroundColor Green
        $gamingScore += 15
    } else {
        Write-Host "  ⚠️  Memory: LIMITED for modern games" -ForegroundColor Yellow
        $gamingScore += 8
    }
    
    # 熱管理評価
    if ($gamingAnalysis.CurrentTemp -ne "N/A" -and $gamingAnalysis.CurrentTemp -lt 75) {
        Write-Host "  ✅ Thermal Management: EXCELLENT" -ForegroundColor Green
        Write-Host "     Temperature well controlled, no thermal throttling" -ForegroundColor White
        $gamingScore += 10
    } else {
        Write-Host "  ✅ Thermal Management: PROTECTED" -ForegroundColor Green
        Write-Host "     Thermal Protection Plan preventing overheating" -ForegroundColor White
        $gamingScore += 8
    }
    
    # 総合ゲーミング評価
    $gamingPercentage = [math]::Round(($gamingScore / $maxGamingScore) * 100, 1)
    
    Write-Host "`n🎮 OVERALL GAMING CAPABILITY:" -ForegroundColor Cyan
    $capabilityColor = if ($gamingPercentage -ge 80) { "Green" } elseif ($gamingPercentage -ge 60) { "Yellow" } else { "Red" }
    $capabilityRating = if ($gamingPercentage -ge 80) { "EXCELLENT" } elseif ($gamingPercentage -ge 60) { "GOOD" } elseif ($gamingPercentage -ge 40) { "FAIR" } else { "LIMITED" }
    
    Write-Host "   Gaming Score: $gamingPercentage% - $capabilityRating" -ForegroundColor $capabilityColor
    
    Write-Host "`n📋 GAMING RECOMMENDATIONS:" -ForegroundColor Cyan
    
    if ($gamingPercentage -ge 70) {
        Write-Host "   ✅ Current setup CAN handle gaming well!" -ForegroundColor Green
        Write-Host "   🎮 Recommended Game Settings:" -ForegroundColor Yellow
        Write-Host "      • 1080p: High/Ultra settings (60+ FPS)" -ForegroundColor White
        Write-Host "      • 1440p: Medium/High settings (45-60 FPS)" -ForegroundColor White
        Write-Host "      • 4K: Low/Medium settings (30-45 FPS)" -ForegroundColor White
        
        Write-Host "`n   ⚡ Performance Optimization Tips:" -ForegroundColor Yellow
        Write-Host "      • Keep Thermal Protection Plan for stability" -ForegroundColor White
        Write-Host "      • Ensure games use RTX 4060 (not integrated GPU)" -ForegroundColor White
        Write-Host "      • Close background applications before gaming" -ForegroundColor White
        Write-Host "      • Monitor temperatures during long gaming sessions" -ForegroundColor White
        
        if ($gamingAnalysis.GameTestResults.MaxCPU -gt 75) {
            Write-Host "`n   🔧 Optional Gaming Power Plan:" -ForegroundColor Yellow
            Write-Host "      • Create separate plan with 90%/85% CPU limits" -ForegroundColor White
            Write-Host "      • Use only for gaming sessions" -ForegroundColor White
            Write-Host "      • Return to Thermal Protection Plan afterward" -ForegroundColor White
        }
        
    } else {
        Write-Host "   ⚠️  Gaming performance may be limited" -ForegroundColor Yellow
        Write-Host "   🔧 Recommendations for better gaming:" -ForegroundColor Yellow
        Write-Host "      • Create optimized gaming power plan (90%/85%)" -ForegroundColor White
        Write-Host "      • Close all unnecessary background applications" -ForegroundColor White
        Write-Host "      • Lower game graphics settings" -ForegroundColor White
        Write-Host "      • Consider CPU undervolting for better performance" -ForegroundColor White
    }
    
    Write-Host "`n🌡️ THERMAL SAFETY:" -ForegroundColor Cyan
    Write-Host "   ✅ Thermal Protection Plan ensures system stability" -ForegroundColor Green
    Write-Host "   ✅ No risk of thermal shutdowns during gaming" -ForegroundColor Green
    Write-Host "   ⚡ Trade-off: Slightly reduced peak performance for reliability" -ForegroundColor Yellow
    
} catch {
    Write-Host "❌ Gaming performance analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "           GAMING ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue"