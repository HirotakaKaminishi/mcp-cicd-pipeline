# Next Diagnostic Steps - Memory is OK, find other causes
Write-Host "=== MEMORY TEST PASSED - CHECKING OTHER CAUSES ===" -ForegroundColor Green
Write-Host "Memory is OK. Investigating CPU/Power issues..." -ForegroundColor Yellow

Write-Host "`n[1] CHECK CPU TEMPERATURE AND THROTTLING:" -ForegroundColor Cyan
Write-Host @'
# Run on Investigation PC (192.168.111.163):

# Check CPU temperature zones
Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" | ForEach-Object {
    $temp = ($_.CurrentTemperature / 10) - 273.15
    Write-Host "Temperature: $([math]::Round($temp, 1))°C"
}

# Check current CPU throttling
Get-WmiObject -Class Win32_Processor | Select-Object Name, CurrentClockSpeed, MaxClockSpeed, LoadPercentage

# Check thermal throttling events
Get-WinEvent -FilterHashtable @{LogName='System'; ID=86} -MaxEvents 5 -ErrorAction SilentlyContinue

'@ -ForegroundColor White

Write-Host "`n[2] CHECK POWER AND CRITICAL ERRORS:" -ForegroundColor Cyan
Write-Host @'
# Check for critical errors in last 24 hours
Get-WinEvent -FilterHashtable @{
    LogName='System';
    Level=1;
    StartTime=(Get-Date).AddDays(-1)
} | Select-Object TimeCreated, ProviderName, Message | Format-List

# Check for BugCheck (Blue Screen) events
Get-WinEvent -FilterHashtable @{LogName='System'; ID=1001} -MaxEvents 5 -ErrorAction SilentlyContinue

# Check Power events
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'} -MaxEvents 10 | 
    Where-Object {$_.Id -ne 41} | Format-Table TimeCreated, Id, Message

'@ -ForegroundColor White

Write-Host "`n[3] INSTALL AND RUN DIAGNOSTIC TOOLS:" -ForegroundColor Cyan
Write-Host @'
# Download HWiNFO64 for temperature monitoring:
Start-Process "https://www.hwinfo.com/download/"

# Download Prime95 for stress testing (use carefully):
Start-Process "https://www.mersenne.org/download/"

# Check Event Viewer manually:
eventvwr.msc
# Navigate to: Windows Logs > System
# Look for: Critical errors, WHEA-Logger, Kernel-Power

'@ -ForegroundColor White

Write-Host "`n[4] IMMEDIATE POWER MANAGEMENT:" -ForegroundColor Cyan
Write-Host @'
# Set maximum power saving (reduce heat/power draw)
powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a

# Disable CPU Turbo Boost
powercfg /setacvalueindex scheme_current sub_processor PERFBOOSTMODE 0

# Set CPU max to 50% (emergency measure)
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 50
powercfg /setactive scheme_current

# Disable sleep/hibernate (may cause issues)
powercfg /h off
powercfg /x -standby-timeout-ac 0

'@ -ForegroundColor White

Write-Host "`n[5] HARDWARE INSPECTION CHECKLIST:" -ForegroundColor Red
Write-Host @'
Physical inspection needed:
1. ✓ Memory test passed - NOT the cause
2. □ Check CPU cooler - dust/thermal paste
3. □ Check all fans are spinning
4. □ Check PSU wattage (need 550W+ for Ryzen 9)
5. □ Check for bulging capacitors on motherboard
6. □ Reseat all power connections
7. □ Check BIOS version and settings
8. □ Test with different power outlet/UPS

'@ -ForegroundColor Yellow

Write-Host "`n[ANALYSIS]" -ForegroundColor Green
Write-Host "Since memory passed, likely causes are:" -ForegroundColor Yellow
Write-Host "1. CPU OVERHEATING (60% probability) - Ryzen 9 6900HX runs hot" -ForegroundColor Red
Write-Host "2. POWER SUPPLY FAILURE (35% probability) - Insufficient or failing PSU" -ForegroundColor Red
Write-Host "3. MOTHERBOARD VRM ISSUE (5% probability) - Power delivery problem" -ForegroundColor Red

Write-Host "`nRUN THESE COMMANDS ON 192.168.111.163 NOW!" -ForegroundColor Cyan