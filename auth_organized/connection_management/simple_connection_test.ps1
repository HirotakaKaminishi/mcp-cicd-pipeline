# シンプルな接続テストスクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "Testing connection to $targetPC..." -ForegroundColor Yellow

# ネットワーク接続テスト
Write-Host "1. Network connectivity test..." -ForegroundColor Cyan
$pingResult = Test-Connection -ComputerName $targetPC -Count 2 -Quiet -ErrorAction SilentlyContinue

if ($pingResult) {
    Write-Host "   Network: ONLINE" -ForegroundColor Green
    
    # PowerShell接続テスト
    Write-Host "2. PowerShell remoting test..." -ForegroundColor Cyan
    try {
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
        
        $remoteResult = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            return "Connection successful at $(Get-Date)"
        } -ErrorAction Stop
        
        Write-Host "   PowerShell: ONLINE" -ForegroundColor Green
        Write-Host "   Response: $remoteResult" -ForegroundColor White
        
        # システムスペック取得
        Write-Host "`n3. Getting system specifications..." -ForegroundColor Cyan
        
        $systemSpecs = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            $specs = @{}
            
            # CPU情報
            $cpu = Get-WmiObject Win32_Processor
            $specs.CPUName = $cpu.Name
            $specs.CPUCores = $cpu.NumberOfCores
            $specs.CPULogicalProcessors = $cpu.NumberOfLogicalProcessors
            $specs.CPUMaxClockSpeed = $cpu.MaxClockSpeed
            
            # メモリ情報
            $os = Get-WmiObject Win32_OperatingSystem
            $specs.TotalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            
            # システム情報
            $computer = Get-WmiObject Win32_ComputerSystem
            $specs.ComputerName = $computer.Name
            $specs.Manufacturer = $computer.Manufacturer
            $specs.Model = $computer.Model
            
            # OS情報
            $specs.OSVersion = $os.Caption
            $specs.OSArchitecture = $os.OSArchitecture
            
            # 起動時間
            $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
            $uptime = (Get-Date) - $lastBoot
            $specs.LastBoot = $lastBoot
            $specs.Uptime = "$($uptime.Hours)h $($uptime.Minutes)m"
            
            # 電源プラン
            $activePlan = powercfg /getactivescheme
            $specs.ActivePowerPlan = $activePlan
            
            return $specs
        }
        
        Write-Host "`n" + "=" * 60 -ForegroundColor Green
        Write-Host "           SYSTEM SPECIFICATIONS" -ForegroundColor Green
        Write-Host "=" * 60 -ForegroundColor Green
        
        Write-Host "`nComputer Information:" -ForegroundColor Cyan
        Write-Host "  Computer Name: $($systemSpecs.ComputerName)" -ForegroundColor White
        Write-Host "  Manufacturer: $($systemSpecs.Manufacturer)" -ForegroundColor White
        Write-Host "  Model: $($systemSpecs.Model)" -ForegroundColor White
        
        Write-Host "`nCPU Information:" -ForegroundColor Cyan
        Write-Host "  Processor: $($systemSpecs.CPUName)" -ForegroundColor White
        Write-Host "  Physical Cores: $($systemSpecs.CPUCores)" -ForegroundColor White
        Write-Host "  Logical Processors: $($systemSpecs.CPULogicalProcessors)" -ForegroundColor White
        Write-Host "  Max Clock Speed: $($systemSpecs.CPUMaxClockSpeed) MHz" -ForegroundColor White
        
        Write-Host "`nMemory Information:" -ForegroundColor Cyan
        Write-Host "  Total Memory: $($systemSpecs.TotalMemoryGB) GB" -ForegroundColor White
        
        Write-Host "`nOperating System:" -ForegroundColor Cyan
        Write-Host "  OS: $($systemSpecs.OSVersion)" -ForegroundColor White
        Write-Host "  Architecture: $($systemSpecs.OSArchitecture)" -ForegroundColor White
        
        Write-Host "`nSystem Status:" -ForegroundColor Cyan
        Write-Host "  Last Boot: $($systemSpecs.LastBoot)" -ForegroundColor White
        Write-Host "  Current Uptime: $($systemSpecs.Uptime)" -ForegroundColor White
        
        Write-Host "`nPower Management:" -ForegroundColor Cyan
        Write-Host "  $($systemSpecs.ActivePowerPlan)" -ForegroundColor Green
        
        if ($systemSpecs.ActivePowerPlan -match "Thermal Protection Plan") {
            Write-Host "`n✅ THERMAL PROTECTION: ACTIVE" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️  THERMAL PROTECTION: NOT ACTIVE" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "   PowerShell: FAILED" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} else {
    Write-Host "   Network: OFFLINE" -ForegroundColor Red
    Write-Host "`nTarget PC appears to be offline or unreachable." -ForegroundColor Red
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "- System is still booting" -ForegroundColor White
    Write-Host "- Network connectivity issues" -ForegroundColor White
    Write-Host "- System encountered boot problems" -ForegroundColor White
    Write-Host "- IP address changed" -ForegroundColor White
}

Read-Host "`nPress Enter to continue"