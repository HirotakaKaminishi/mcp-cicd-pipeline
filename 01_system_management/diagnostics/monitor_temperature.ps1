# Temperature Monitoring Script with Auto-Shutdown Protection
# Runs continuously and shuts down if temperature exceeds threshold

$logFile = "C:\temp_monitor.log"
$maxTemp = 75  # Celsius - conservative threshold
$checkInterval = 5  # seconds

Write-Host "Temperature Monitor Started - Max Temp: $maxTemp°C" -ForegroundColor Green
Add-Content -Path $logFile -Value "$(Get-Date) - Monitor started"

while ($true) {
    try {
        # Get temperature
        $temps = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction SilentlyContinue
        
        if ($temps) {
            foreach ($temp in $temps) {
                $celsius = [math]::Round((($temp.CurrentTemperature / 10) - 273.15), 1)
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                
                # Display and log
                if ($celsius -gt $maxTemp) {
                    $msg = "$timestamp - CRITICAL: $celsius°C - Exceeds threshold!"
                    Write-Host $msg -ForegroundColor Red
                    Add-Content -Path $logFile -Value $msg
                    
                    # Alert and prepare shutdown
                    [System.Windows.MessageBox]::Show("Temperature Critical: $celsius°C`nShutting down in 30 seconds!", "OVERHEAT WARNING", "OK", "Warning")
                    
                    # Give time to save work
                    Start-Sleep -Seconds 30
                    
                    # Safe shutdown
                    Stop-Computer -Force
                    
                } elseif ($celsius -gt 65) {
                    $msg = "$timestamp - WARNING: $celsius°C"
                    Write-Host $msg -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $msg
                } else {
                    $msg = "$timestamp - Normal: $celsius°C"
                    Write-Host $msg -ForegroundColor Green
                }
            }
        } else {
            Write-Host "$(Get-Date) - Temperature sensors not accessible" -ForegroundColor Magenta
        }
        
        # Also check CPU usage
        $cpu = Get-WmiObject Win32_Processor | Select-Object -ExpandProperty LoadPercentage
        if ($cpu -gt 90) {
            Write-Host "High CPU Load: $cpu%" -ForegroundColor Yellow
            
            # Throttle CPU if too high
            powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 70
            powercfg /setactive scheme_current
        }
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds $checkInterval
}