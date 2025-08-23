# Local Emergency Check Script for 192.168.111.163
# Run this directly on the investigation PC

Write-Host "=== LOCAL EMERGENCY DIAGNOSIS ===" -ForegroundColor Red
Write-Host "Run this script directly on the investigation PC (192.168.111.163)" -ForegroundColor Yellow
Write-Host "Time: $(Get-Date)" -ForegroundColor Cyan

# 1. System Information
Write-Host "`n[1] SYSTEM INFORMATION:" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$comp = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
$bios = Get-CimInstance Win32_BIOS

Write-Host "Computer: $($comp.Manufacturer) $($comp.Model)"
Write-Host "CPU: $($cpu.Name)"
Write-Host "Cores: $($cpu.NumberOfCores) | Logical: $($cpu.NumberOfLogicalProcessors)"
Write-Host "RAM: $([math]::Round($comp.TotalPhysicalMemory/1GB, 2)) GB"
Write-Host "BIOS: $($bios.Manufacturer) | Version: $($bios.SMBIOSBIOSVersion)"
Write-Host "Last Boot: $($os.LastBootUpTime)"

# 2. Critical Event Analysis
Write-Host "`n[2] CRITICAL SHUTDOWN EVENTS (Last 10):" -ForegroundColor Yellow
$shutdowns = Get-WinEvent -FilterHashtable @{LogName='System'; ID=41} -MaxEvents 10 -ErrorAction SilentlyContinue
if ($shutdowns) {
    foreach ($event in $shutdowns) {
        Write-Host "$($event.TimeCreated) - Unexpected shutdown detected" -ForegroundColor Red
    }
} else {
    Write-Host "No critical events found"
}

# 3. Temperature Monitoring
Write-Host "`n[3] ATTEMPTING TEMPERATURE READ:" -ForegroundColor Yellow
try {
    # Try WMI method
    $temps = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop
    foreach ($temp in $temps) {
        $celsius = ($temp.CurrentTemperature / 10) - 273.15
        $color = if($celsius -gt 80){"Red"}elseif($celsius -gt 60){"Yellow"}else{"Green"}
        Write-Host "Temperature: $([math]::Round($celsius, 1))°C" -ForegroundColor $color
    }
} catch {
    Write-Host "WMI temperature sensors not available" -ForegroundColor Magenta
    Write-Host "Recommend installing HWiNFO64 or Core Temp for monitoring" -ForegroundColor Cyan
}

# 4. Power Configuration
Write-Host "`n[4] POWER SETTINGS:" -ForegroundColor Yellow
powercfg /getactivescheme

# 5. Memory Diagnostic
Write-Host "`n[5] MEMORY STATUS:" -ForegroundColor Yellow
$memoryStatus = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
$usedMemory = ($memoryStatus.TotalVisibleMemorySize - $memoryStatus.FreePhysicalMemory) / 1MB
$totalMemory = $memoryStatus.TotalVisibleMemorySize / 1MB
Write-Host "Memory Usage: $([math]::Round($usedMemory, 2)) GB / $([math]::Round($totalMemory, 2)) GB"
Write-Host "To run full memory test: mdsched.exe" -ForegroundColor Cyan

# 6. Disk Health
Write-Host "`n[6] DISK HEALTH:" -ForegroundColor Yellow
Get-PhysicalDisk | ForEach-Object {
    Write-Host "$($_.FriendlyName) - Health: $($_.HealthStatus) | Status: $($_.OperationalStatus)"
}

# 7. Event Log Summary
Write-Host "`n[7] ERROR EVENT SUMMARY (Last 24 hours):" -ForegroundColor Yellow
$yesterday = (Get-Date).AddDays(-1)
$errors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$yesterday} -ErrorAction SilentlyContinue
if ($errors) {
    $grouped = $errors | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 5
    foreach ($group in $grouped) {
        Write-Host "$($group.Name): $($group.Count) errors" -ForegroundColor Red
    }
}

# 8. Recommendations
Write-Host "`n[8] IMMEDIATE ACTIONS RECOMMENDED:" -ForegroundColor Green
Write-Host "1. Install HWiNFO64 for temperature monitoring"
Write-Host "2. Run memory diagnostic: mdsched.exe"
Write-Host "3. Check Event Viewer for BugCheck codes"
Write-Host "4. Update BIOS if newer version available"
Write-Host "5. Test with one RAM stick at a time"
Write-Host "6. Check PSU wattage (should be 650W+ for Ryzen 9)"

Write-Host "`n=== SAVE THIS OUTPUT FOR ANALYSIS ===" -ForegroundColor Cyan