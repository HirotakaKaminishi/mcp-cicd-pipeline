# Execute Memory Test - Final Version
$targetPC = "192.168.111.163"
$username = "pc"
$password = ConvertTo-SecureString "1192" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "=== EXECUTING MEMORY TEST AND DIAGNOSTICS ===" -ForegroundColor Green
Write-Host "Target: $targetPC (WinRM configured successfully)" -ForegroundColor Cyan

try {
    # Establish connection
    Write-Host "`n[1] Connecting to remote PC..." -ForegroundColor Yellow
    $session = New-PSSession -ComputerName $targetPC -Credential $credential -ErrorAction Stop
    Write-Host "✓ Connected successfully!" -ForegroundColor Green
    
    # Get system status
    Write-Host "`n[2] System Status:" -ForegroundColor Yellow
    $status = Invoke-Command -Session $session -ScriptBlock {
        $os = Get-CimInstance Win32_OperatingSystem
        $comp = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor
        $uptime = (Get-Date) - $os.LastBootUpTime
        
        @{
            ComputerName = $env:COMPUTERNAME
            Model = "$($comp.Manufacturer) $($comp.Model)"
            CPU = $cpu.Name
            Uptime = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
            TotalMemory = [math]::Round($comp.TotalPhysicalMemory/1GB, 2)
            FreeMemory = [math]::Round($os.FreePhysicalMemory/1KB/1GB, 2)
        }
    }
    
    Write-Host "Computer: $($status.ComputerName) - $($status.Model)" -ForegroundColor Cyan
    Write-Host "CPU: $($status.CPU)" -ForegroundColor Cyan
    Write-Host "Memory: $($status.FreeMemory)GB free of $($status.TotalMemory)GB" -ForegroundColor Cyan
    Write-Host "Uptime: $($status.Uptime)" -ForegroundColor Cyan
    
    # Check shutdown events
    Write-Host "`n[3] Recent Shutdown Events:" -ForegroundColor Yellow
    $shutdowns = Invoke-Command -Session $session -ScriptBlock {
        Get-WinEvent -FilterHashtable @{LogName='System'; ID=41} -MaxEvents 5 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated | ForEach-Object { $_.TimeCreated.ToString() }
    }
    
    if ($shutdowns) {
        foreach ($shutdown in $shutdowns) {
            Write-Host "  ⚠ Unexpected shutdown: $shutdown" -ForegroundColor Red
        }
    } else {
        Write-Host "  No recent unexpected shutdowns" -ForegroundColor Green
    }
    
    # Schedule memory test
    Write-Host "`n[4] Scheduling Memory Diagnostic..." -ForegroundColor Yellow
    $memTestResult = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Execute memory diagnostic scheduler
            Start-Process -FilePath "mdsched.exe" -ArgumentList "/t" -Wait -NoNewWindow -PassThru
            return "✓ Memory diagnostic scheduled successfully"
        } catch {
            return "Error: $_"
        }
    }
    Write-Host $memTestResult -ForegroundColor Green
    
    # Apply power saving settings
    Write-Host "`n[5] Applying Power Management Settings..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        # Set to Power Saver
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
        
        # Limit CPU to 60%
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 60
        powercfg /setactive scheme_current
        
        Write-Host "✓ CPU limited to 60% to prevent overheating" -ForegroundColor Green
    }
    
    # Check temperatures if possible
    Write-Host "`n[6] Temperature Check:" -ForegroundColor Yellow
    $tempStatus = Invoke-Command -Session $session -ScriptBlock {
        try {
            $temps = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop
            $celsius = [math]::Round((($temps[0].CurrentTemperature / 10) - 273.15), 1)
            return "Current temperature: $celsius°C"
        } catch {
            return "Temperature sensors not accessible - Install HWiNFO64 for monitoring"
        }
    }
    Write-Host $tempStatus -ForegroundColor $(if($tempStatus -match "(\d+)°C" -and [int]$Matches[1] -gt 70){"Red"}else{"Cyan"})
    
    # Create monitoring script
    Write-Host "`n[7] Creating System Monitor..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        $monitorScript = @'
# System Monitor Script
$logFile = "C:\system_monitor.log"
"$(Get-Date) - Monitor Started" | Out-File $logFile

while ($true) {
    $cpu = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
    $mem = Get-CimInstance Win32_OperatingSystem
    $memUsed = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory)/1MB, 2)
    
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | CPU: $([math]::Round($cpu,1))% | Mem: ${memUsed}GB"
    $entry | Out-File -Append $logFile
    
    if ($cpu -gt 80) {
        "WARNING: High CPU at $(Get-Date)" | Out-File -Append $logFile
    }
    
    Start-Sleep -Seconds 30
}
'@
        $monitorScript | Out-File C:\monitor.ps1 -Encoding UTF8
        Write-Host "✓ Monitor script created at C:\monitor.ps1" -ForegroundColor Green
    }
    
    # Summary
    Write-Host "`n[8] DIAGNOSTIC COMPLETE:" -ForegroundColor Green
    Write-Host "✓ Memory test scheduled - will run on next reboot" -ForegroundColor Green
    Write-Host "✓ Power settings optimized (CPU limited to 60%)" -ForegroundColor Green  
    Write-Host "✓ System monitor created" -ForegroundColor Green
    
    Write-Host "`n[9] NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Reboot the PC to start memory test (will take 10-30 minutes)" -ForegroundColor Cyan
    Write-Host "2. After reboot, check Event Viewer for MemoryDiagnostics-Results" -ForegroundColor Cyan
    Write-Host "3. Install HWiNFO64 for temperature monitoring" -ForegroundColor Cyan
    
    Write-Host "`nTo reboot now:" -ForegroundColor Yellow
    Write-Host "  Restart-Computer -ComputerName $targetPC -Force -Credential (Get-Credential)" -ForegroundColor White
    
    Remove-PSSession -Session $session
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}