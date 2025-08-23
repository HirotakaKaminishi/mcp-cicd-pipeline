$cred = New-Object System.Management.Automation.PSCredential("pc", (ConvertTo-SecureString "1192" -AsPlainText -Force))

Invoke-Command -ComputerName 192.168.111.163 -Credential $cred -ScriptBlock { 
    Write-Host "=== EMERGENCY SYSTEM DIAGNOSIS ===" -ForegroundColor Red
    Write-Host "Time: $(Get-Date)" -ForegroundColor Cyan
    
    # 1. Hardware and System Info
    Write-Host "`n[1] HARDWARE STATUS:" -ForegroundColor Yellow
    $cpu = Get-WmiObject Win32_Processor | Select-Object Name, CurrentClockSpeed, MaxClockSpeed, LoadPercentage, NumberOfCores
    $memory = Get-WmiObject Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
    $comp = Get-WmiObject Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory
    
    Write-Host "System: $($comp.Manufacturer) $($comp.Model)"
    Write-Host "CPU: $($cpu.Name)"
    Write-Host "Cores: $($cpu.NumberOfCores)"
    Write-Host "CPU Load: $($cpu.LoadPercentage)%"
    Write-Host "Memory Used: $([math]::Round(($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory)/1MB, 2)) GB / $([math]::Round($memory.TotalVisibleMemorySize/1MB, 2)) GB"
    
    # 2. Temperature Check (if available)
    Write-Host "`n[2] THERMAL STATUS:" -ForegroundColor Yellow
    try {
        $thermalZones = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop
        foreach ($zone in $thermalZones) {
            $tempKelvin = $zone.CurrentTemperature / 10
            $tempCelsius = $tempKelvin - 273.15
            Write-Host "Zone Temperature: $([math]::Round($tempCelsius, 1))°C" -ForegroundColor $(if($tempCelsius -gt 80){"Red"}elseif($tempCelsius -gt 60){"Yellow"}else{"Green"})
        }
    } catch {
        Write-Host "Thermal data not accessible - Installing monitoring tools recommended" -ForegroundColor Magenta
    }
    
    # 3. Last shutdown events
    Write-Host "`n[3] RECENT CRITICAL EVENTS:" -ForegroundColor Yellow
    $events = Get-EventLog -LogName System -Source "Microsoft-Windows-Kernel-Power" -Newest 10 -ErrorAction SilentlyContinue
    if ($events) {
        $events | Where-Object {$_.EventID -eq 41} | Select-Object -First 5 TimeGenerated, EventID, Message | Format-Table -AutoSize
    }
    
    # 4. Power Settings
    Write-Host "`n[4] POWER CONFIGURATION:" -ForegroundColor Yellow
    $powerPlan = powercfg /getactivescheme
    Write-Host $powerPlan
    
    # 5. System Uptime
    Write-Host "`n[5] SYSTEM UPTIME:" -ForegroundColor Yellow
    $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    Write-Host "System has been running for: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    
    # 6. Disk Health
    Write-Host "`n[6] DISK HEALTH:" -ForegroundColor Yellow
    Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size | Format-Table -AutoSize
    
    # 7. Running Processes by CPU
    Write-Host "`n[7] TOP CPU CONSUMING PROCESSES:" -ForegroundColor Yellow
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, WorkingSet, Id | Format-Table -AutoSize
    
    Write-Host "`n=== DIAGNOSIS COMPLETE ===" -ForegroundColor Green
}