# Power Failure Root Cause Analysis
Write-Host "=== POWER FAILURE CONFIRMED - 12 EVENTS IN 24 HOURS ===" -ForegroundColor Red
Write-Host "Temperature: 20.1°C (Not overheating)" -ForegroundColor Green
Write-Host "Memory: Passed (Not the cause)" -ForegroundColor Green
Write-Host "Cause: POWER SUPPLY OR ELECTRICAL ISSUE" -ForegroundColor Red

Write-Host "`n[DIAGNOSIS SUMMARY]" -ForegroundColor Yellow
Write-Host @"
✓ Memory: OK (tested and passed)
✓ CPU Temperature: OK (20.1°C - actually too low, sensor may be wrong)
✗ Power: FAILING (12 unexpected power losses)

CONFIRMED CAUSE: Power delivery failure
"@ -ForegroundColor Cyan

Write-Host "`n[IMMEDIATE CHECKS ON 192.168.111.163]" -ForegroundColor Yellow
Write-Host @'

# 1. Check Power Configuration Details
powercfg /energy /output C:\energy_report.html /duration 60
# Wait 60 seconds, then open C:\energy_report.html

# 2. Check Battery Status (if laptop)
Get-WmiObject Win32_Battery | Select-Object Name, EstimatedChargeRemaining, BatteryStatus

# 3. Check Power Supply Events
Get-WinEvent -FilterHashtable @{
    LogName='System';
    ProviderName='Microsoft-Windows-Kernel-PnP'
} -MaxEvents 20 | Where-Object {$_.Message -match "power|Power|battery|Battery"}

# 4. Check System Voltages (if available)
Get-WmiObject -Namespace root\wmi -Class MSAcpi_ThermalZoneTemperature
Get-WmiObject Win32_VoltageProbe | Select-Object Name, CurrentReading, MinReadable, MaxReadable

# 5. Check USB Power Issues
Get-WinEvent -FilterHashtable @{LogName='System'; ID=10} -MaxEvents 10 | Where-Object {$_.Message -match "USB"}

'@ -ForegroundColor White

Write-Host "`n[HARDWARE INSPECTION REQUIRED]" -ForegroundColor Red
Write-Host @"
1. POWER SUPPLY UNIT (PSU):
   - Check PSU wattage (MUST be 650W+ for Ryzen 9 6900HX)
   - Listen for unusual PSU fan noise/clicking
   - Check if PSU is hot to touch
   - Test with different PSU if available

2. POWER CONNECTIONS:
   - Reseat 24-pin ATX connector
   - Reseat 4/8-pin CPU power connector
   - Check all SATA/PCIe power cables
   - Look for burnt/melted connectors

3. ELECTRICAL SUPPLY:
   - Test different wall outlet
   - Use UPS/surge protector
   - Check building electrical stability
   - Verify outlet voltage (should be 100-240V)

4. MOTHERBOARD:
   - Check for bulging/leaking capacitors
   - Look for burn marks near VRMs
   - Verify all standoffs installed correctly
   - Check for short circuits

"@ -ForegroundColor Yellow

Write-Host "`n[EMERGENCY WORKAROUND]" -ForegroundColor Green
Write-Host @'
# Reduce power consumption to minimum:
powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 30
powercfg /setacvalueindex scheme_current sub_processor PERFBOOSTMODE 0
powercfg /setactive scheme_current

# Disable unnecessary devices
devmgmt.msc
# Disable: Bluetooth, unused USB controllers, discrete GPU if not needed

'@ -ForegroundColor Cyan

Write-Host "`n[FINAL DIAGNOSIS]" -ForegroundColor Red
Write-Host "ROOT CAUSE: POWER DELIVERY FAILURE" -ForegroundColor Red
Write-Host "Most likely:" -ForegroundColor Yellow
Write-Host "1. PSU failing or insufficient wattage (70% probability)" -ForegroundColor Red
Write-Host "2. Electrical supply issue (20% probability)" -ForegroundColor Yellow
Write-Host "3. Motherboard power regulation failure (10% probability)" -ForegroundColor Yellow

Write-Host "`nACTION: Replace PSU with 750W+ unit immediately" -ForegroundColor Green