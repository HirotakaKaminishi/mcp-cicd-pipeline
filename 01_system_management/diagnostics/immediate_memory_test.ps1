# Immediate Memory Test and Emergency Diagnosis
# Execute the moment PC comes online

$targetPC = "192.168.111.163"
$username = "pc"
$password = ConvertTo-SecureString "1192" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "=== IMMEDIATE MEMORY TEST EXECUTION ===" -ForegroundColor Red
Write-Host "Target: $targetPC" -ForegroundColor Yellow

# Test connectivity first
Write-Host "`n[1] Testing connection..." -ForegroundColor Yellow
if (Test-Connection -ComputerName $targetPC -Count 1 -Quiet) {
    Write-Host "✓ PC is online!" -ForegroundColor Green
    
    try {
        Write-Host "`n[2] Establishing remote session..." -ForegroundColor Yellow
        $session = New-PSSession -ComputerName $targetPC -Credential $cred -ErrorAction Stop
        
        Write-Host "✓ Remote session established!" -ForegroundColor Green
        
        # Immediate system status
        Write-Host "`n[3] Getting current system status..." -ForegroundColor Yellow
        $status = Invoke-Command -Session $session -ScriptBlock {
            $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            $memory = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
            $cpu = Get-CimInstance Win32_Processor | Select-Object LoadPercentage
            
            @{
                Uptime = "$($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s"
                MemoryUsed = [math]::Round(($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory)/1MB, 2)
                MemoryTotal = [math]::Round($memory.TotalVisibleMemorySize/1MB, 2)
                CPULoad = $cpu.LoadPercentage
            }
        }
        
        Write-Host "Uptime: $($status.Uptime)" -ForegroundColor Cyan
        Write-Host "Memory: $($status.MemoryUsed)GB / $($status.MemoryTotal)GB" -ForegroundColor Cyan
        Write-Host "CPU Load: $($status.CPULoad)%" -ForegroundColor Cyan
        
        # Schedule memory test
        Write-Host "`n[4] Scheduling Windows Memory Diagnostic..." -ForegroundColor Yellow
        $memResult = Invoke-Command -Session $session -ScriptBlock {
            try {
                # Schedule memory test for next reboot
                mdsched.exe /t
                return "Memory diagnostic scheduled for next reboot"
            } catch {
                return "Error scheduling memory test: $_"
            }
        }
        
        Write-Host $memResult -ForegroundColor Green
        
        # Get recent critical events
        Write-Host "`n[5] Checking for new critical events..." -ForegroundColor Yellow
        $events = Invoke-Command -Session $session -ScriptBlock {
            Get-WinEvent -FilterHashtable @{LogName='System'; ID=41} -MaxEvents 5 -ErrorAction SilentlyContinue |
            Select-Object TimeCreated, Message | Format-Table -AutoSize | Out-String
        }
        
        if ($events) {
            Write-Host $events
        } else {
            Write-Host "No new critical events found" -ForegroundColor Green
        }
        
        # Quick temperature check
        Write-Host "`n[6] Attempting temperature reading..." -ForegroundColor Yellow
        $tempResult = Invoke-Command -Session $session -ScriptBlock {
            try {
                $temps = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop
                $results = @()
                foreach ($temp in $temps) {
                    $celsius = [math]::Round((($temp.CurrentTemperature / 10) - 273.15), 1)
                    $results += "Temperature: $celsius°C"
                }
                return $results -join "`n"
            } catch {
                return "Temperature sensors not accessible"
            }
        }
        
        Write-Host $tempResult -ForegroundColor $(if($tempResult -match "\d+°C" -and [int]($tempResult -replace ".*(\d+)°C.*",'$1') -gt 70){"Red"}else{"Cyan"})
        
        # Set power saving mode
        Write-Host "`n[7] Applying power-saving settings..." -ForegroundColor Yellow
        Invoke-Command -Session $session -ScriptBlock {
            # Set to power saver mode
            powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
            
            # Limit CPU to 70%
            powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 70
            powercfg /setactive scheme_current
        }
        
        Write-Host "✓ Power-saving mode applied" -ForegroundColor Green
        
        Remove-PSSession -Session $session
        
        Write-Host "`n=== IMMEDIATE DIAGNOSTICS COMPLETE ===" -ForegroundColor Green
        Write-Host "Next: Reboot the PC to run memory test" -ForegroundColor Yellow
        
    } catch {
        Write-Host "✗ Failed to connect: $_" -ForegroundColor Red
    }
    
} else {
    Write-Host "✗ PC appears to be offline" -ForegroundColor Red
    Write-Host "Waiting for PC to come online..." -ForegroundColor Yellow
}