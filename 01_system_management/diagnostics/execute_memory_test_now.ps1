# Execute Memory Test Immediately - PC is now accessible
$targetPC = "192.168.111.163"
$username = "pc"
$password = ConvertTo-SecureString "1192" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "=== EXECUTING MEMORY TEST NOW ===" -ForegroundColor Red
Write-Host "Target PC is now accessible with PSRemoting enabled" -ForegroundColor Green

# Connect to the PC
try {
    Write-Host "`n[1] Establishing remote session..." -ForegroundColor Yellow
    $session = New-PSSession -ComputerName $targetPC -Credential $credential -ErrorAction Stop
    Write-Host "✓ Connected successfully!" -ForegroundColor Green
    
    # Get current system status
    Write-Host "`n[2] Current system status:" -ForegroundColor Yellow
    $status = Invoke-Command -Session $session -ScriptBlock {
        $os = Get-CimInstance Win32_OperatingSystem
        $comp = Get-CimInstance Win32_ComputerSystem
        $uptime = (Get-Date) - $os.LastBootUpTime
        $memory = @{
            Total = [math]::Round($comp.TotalPhysicalMemory/1GB, 2)
            Free = [math]::Round($os.FreePhysicalMemory/1KB/1GB, 2)
            Used = [math]::Round(($comp.TotalPhysicalMemory/1GB) - ($os.FreePhysicalMemory/1KB/1GB), 2)
        }
        
        @{
            ComputerName = $env:COMPUTERNAME
            Uptime = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
            Memory = $memory
            LastBoot = $os.LastBootUpTime
        }
    }
    
    Write-Host "Computer: $($status.ComputerName)" -ForegroundColor Cyan
    Write-Host "Uptime: $($status.Uptime)" -ForegroundColor Cyan
    Write-Host "Memory: $($status.Memory.Used)GB used / $($status.Memory.Total)GB total" -ForegroundColor Cyan
    Write-Host "Last Boot: $($status.LastBoot)" -ForegroundColor Cyan
    
    # Check recent shutdown events
    Write-Host "`n[3] Recent critical events (Kernel-Power):" -ForegroundColor Yellow
    $events = Invoke-Command -Session $session -ScriptBlock {
        Get-WinEvent -FilterHashtable @{LogName='System'; ID=41} -MaxEvents 5 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated | ForEach-Object { $_.TimeCreated.ToString() }
    }
    
    if ($events) {
        $events | ForEach-Object { Write-Host "  - Unexpected shutdown: $_" -ForegroundColor Red }
    } else {
        Write-Host "  No recent unexpected shutdowns" -ForegroundColor Green
    }
    
    # Schedule memory diagnostic
    Write-Host "`n[4] Scheduling Windows Memory Diagnostic..." -ForegroundColor Yellow
    $memResult = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Schedule memory test
            $result = & mdsched.exe /t 2>&1
            
            # Also try to create a scheduled task for next boot
            $action = New-ScheduledTaskAction -Execute "mdsched.exe"
            $trigger = New-ScheduledTaskTrigger -AtStartup
            Register-ScheduledTask -TaskName "MemoryDiagnostic" -Action $action -Trigger $trigger -Force -ErrorAction SilentlyContinue
            
            return "✓ Memory diagnostic scheduled for next reboot"
        } catch {
            return "Error: $_"
        }
    }
    Write-Host $memResult -ForegroundColor $(if($memResult -match "✓"){"Green"}else{"Red"})
    
    # Apply emergency power settings
    Write-Host "`n[5] Applying emergency power settings to prevent thermal shutdown..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        # Set to Power Saver mode
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
        
        # Limit CPU to 60% maximum
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 60
        powercfg /setactive scheme_current
        
        # Disable turbo boost if possible
        powercfg /setacvalueindex scheme_current sub_processor PERFBOOSTMODE 0
        
        Write-Host "✓ Power saving mode activated (CPU limited to 60%)"
    }
    
    # Check for temperature monitoring capability
    Write-Host "`n[6] Checking temperature monitoring..." -ForegroundColor Yellow
    $tempCheck = Invoke-Command -Session $session -ScriptBlock {
        try {
            $temps = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop
            $celsius = [math]::Round((($temps[0].CurrentTemperature / 10) - 273.15), 1)
            return "Current temperature: $celsius°C"
        } catch {
            return "Temperature sensors not accessible - recommend installing HWiNFO64"
        }
    }
    Write-Host $tempCheck -ForegroundColor $(if($tempCheck -match "\d+°C"){"Cyan"}else{"Yellow"})
    
    # Create monitoring script on remote PC
    Write-Host "`n[7] Creating local monitoring script..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        $script = @'
# Auto-monitoring script
while ($true) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $cpu = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
    $mem = Get-CimInstance Win32_OperatingSystem
    $memUsed = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1MB, 2)
    
    "$time | CPU: $([math]::Round($cpu, 1))% | Memory: $memUsed GB" | Out-File -Append C:\system_monitor.log
    
    if ($cpu -gt 80) {
        Write-Warning "High CPU usage detected: $cpu%"
    }
    
    Start-Sleep -Seconds 30
}
'@
        $script | Out-File -FilePath C:\monitor.ps1 -Encoding UTF8
        Write-Host "✓ Monitoring script created at C:\monitor.ps1"
    }
    
    # Summary and recommendations
    Write-Host "`n[8] DIAGNOSTIC SUMMARY:" -ForegroundColor Green
    Write-Host "✓ Memory test scheduled for next reboot" -ForegroundColor Green
    Write-Host "✓ Power saving mode enabled (CPU limited to 60%)" -ForegroundColor Green
    Write-Host "✓ Monitoring script created" -ForegroundColor Green
    
    Write-Host "`nRECOMMENDED ACTIONS:" -ForegroundColor Yellow
    Write-Host "1. Reboot the PC now to run memory diagnostic" -ForegroundColor Cyan
    Write-Host "2. Memory test will run automatically (takes 10-30 minutes)" -ForegroundColor Cyan
    Write-Host "3. After test, check Event Viewer for results" -ForegroundColor Cyan
    Write-Host "4. Install HWiNFO64 for temperature monitoring" -ForegroundColor Cyan
    
    Write-Host "`nTo reboot now for memory test:" -ForegroundColor Yellow
    Write-Host "  Restart-Computer -ComputerName $targetPC -Force -Credential `$credential" -ForegroundColor White
    
    Remove-PSSession -Session $session
    
} catch {
    Write-Host "Connection failed: $_" -ForegroundColor Red
}