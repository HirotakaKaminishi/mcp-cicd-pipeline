# GPU Power Configuration Diagnosis
Write-Host "=== GPU EXTERNAL POWER ISSUE DIAGNOSIS ===" -ForegroundColor Red
Write-Host "Checking GPU with separate power supply configuration" -ForegroundColor Yellow

Write-Host "`n[1] CHECK GPU CONFIGURATION:" -ForegroundColor Cyan
Write-Host @'
# Run on Investigation PC (192.168.111.163):

# Check installed GPUs
Get-WmiObject Win32_VideoController | Select-Object Name, Status, AdapterRAM, DriverVersion, VideoProcessor

# Check GPU status in Device Manager
Get-PnpDevice -Class Display | Format-Table Name, Status, Problem

# Check GPU power states
Get-WmiObject -Namespace root\wmi -Class WmiMonitorBrightness -ErrorAction SilentlyContinue

'@ -ForegroundColor White

Write-Host "`n[2] NVIDIA GPU POWER CHECK:" -ForegroundColor Cyan
Write-Host @'
# If NVIDIA GPU present:
nvidia-smi -q -d POWER

# Alternative command:
& "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" -q | Select-String "Power"

'@ -ForegroundColor White

Write-Host "`n[3] GPU POWER EVENTS:" -ForegroundColor Cyan
Write-Host @'
# Check for GPU-related errors
Get-WinEvent -FilterHashtable @{LogName='System'} -MaxEvents 100 | 
    Where-Object {$_.Message -match "display|Display|GPU|graphics|Graphics|NVIDIA|AMD|Radeon"}

# Check for PCIe power errors
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-PnP'} -MaxEvents 50 |
    Where-Object {$_.Message -match "power|Power"}

'@ -ForegroundColor White

Write-Host "`n[CRITICAL ISSUE IDENTIFIED]" -ForegroundColor Red
Write-Host @"

DUAL POWER SUPPLY CONFIGURATION PROBLEMS:

1. SYNCHRONIZATION ISSUE:
   - Main PSU and GPU PSU may not be synchronized
   - When GPU PSU fails/delays, system loses stability
   - This causes immediate shutdown (Kernel-Power 41)

2. GROUND LOOP PROBLEM:
   - Two separate PSUs can create ground potential difference
   - This causes electrical instability
   - Results in random shutdowns

3. POWER SEQUENCING:
   - GPU PSU may not turn on/off at correct timing
   - Main system expects GPU power but doesn't receive it
   - Triggers protection shutdown

"@ -ForegroundColor Yellow

Write-Host "`n[IMMEDIATE CHECKS]" -ForegroundColor Red
Write-Host @"

PHYSICAL INSPECTION REQUIRED:

1. GPU EXTERNAL PSU:
   □ Check GPU PSU is properly connected
   □ Verify GPU PSU power switch is ON
   □ Check GPU PSU fan is spinning
   □ Listen for clicking/buzzing from GPU PSU
   □ Check all PCIe power cables (6-pin/8-pin)

2. POWER COORDINATION:
   □ Both PSUs plugged into SAME power strip
   □ Both PSUs on same electrical circuit
   □ No loose connections on GPU power cables
   □ GPU properly seated in PCIe slot

3. TEST PROCEDURE:
   □ Disconnect external GPU completely
   □ Run on integrated graphics only
   □ If stable = GPU PSU is the problem
   □ If still crashes = Main PSU issue

"@ -ForegroundColor Cyan

Write-Host "`n[SOLUTIONS]" -ForegroundColor Green
Write-Host @"

OPTION 1: Remove External GPU (Immediate Test)
- Physically remove GPU
- Use integrated Radeon graphics
- Test stability for 1 hour

OPTION 2: Single PSU Solution (Recommended)
- Get single high-wattage PSU (850W+)
- Power both system and GPU from one PSU
- Eliminates synchronization issues

OPTION 3: Fix Dual PSU Setup
- Use PSU synchronization cable (if available)
- Ensure common ground between PSUs
- Use same power outlet/strip for both

"@ -ForegroundColor White

Write-Host "`n[DISABLE GPU TO TEST]" -ForegroundColor Yellow
Write-Host @'
# Disable discrete GPU in Device Manager:
$gpu = Get-PnpDevice -Class Display | Where-Object {$_.Name -match "NVIDIA|GeForce|Radeon RX|RTX"}
if ($gpu) {
    Disable-PnpDevice -InstanceId $gpu.InstanceId -Confirm:$false
    Write-Host "GPU Disabled - Testing integrated graphics only"
}

'@ -ForegroundColor Cyan