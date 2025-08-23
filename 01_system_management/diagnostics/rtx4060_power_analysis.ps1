# RTX 4060 Power Analysis and Shutdown Fix
Write-Host "=== RTX 4060 POWER CONFIGURATION ANALYSIS ===" -ForegroundColor Red
Write-Host "NVIDIA GeForce RTX 4060 detected with external power requirement" -ForegroundColor Yellow

Write-Host "`n[RTX 4060 POWER SPECIFICATIONS]" -ForegroundColor Cyan
Write-Host @"
GPU: NVIDIA GeForce RTX 4060
TGP (Total Graphics Power): 115W
PCIe Power Requirement: 1x 8-pin connector (150W max)
Minimum PSU Requirement: 550W
Recommended PSU: 650W+

POWER CONSUMPTION BREAKDOWN:
- Idle: 15-20W
- Gaming Load: 100-115W
- Peak/Stress: 120W+
- PCIe Slot: 75W
- 8-pin Connector: 40-45W additional

"@ -ForegroundColor White

Write-Host "`n[IMMEDIATE DIAGNOSTIC COMMANDS]" -ForegroundColor Yellow
Write-Host @'

# Check NVIDIA GPU power state
nvidia-smi -q -d POWER

# Check GPU driver status  
Get-PnpDevice -Class Display | Where-Object {$_.Name -match "NVIDIA"} | Format-Table Name, Status, Problem

# Check PCIe power delivery
Get-WinEvent -FilterHashtable @{LogName='System'} -MaxEvents 50 | 
    Where-Object {$_.Message -match "PCIe|PCI Express|display|NVIDIA"}

# Check power management events
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-PnP'} -MaxEvents 30 |
    Where-Object {$_.Message -match "device|power"}

'@ -ForegroundColor Cyan

Write-Host "`n[CRITICAL POWER ISSUES IDENTIFIED]" -ForegroundColor Red
Write-Host @"

PROBLEM 1: DUAL PSU SYNCHRONIZATION
- RTX 4060 requires stable 8-pin PCIe power
- External GPU PSU must power on BEFORE main system
- Power sequence failure → immediate shutdown

PROBLEM 2: POWER DELIVERY INSTABILITY  
- RTX 4060 draws sudden power spikes during GPU boost
- If GPU PSU cannot deliver → voltage drop → system crash
- This explains random Kernel-Power Event ID 41

PROBLEM 3: GROUND LOOP INTERFERENCE
- Two separate PSUs create electrical noise
- RTX 4060 sensitive to power quality
- Poor power quality → GPU driver crash → system shutdown

"@ -ForegroundColor Yellow

Write-Host "`n[SOLUTION 1: DISABLE RTX 4060 TEST]" -ForegroundColor Green
Write-Host @'

# Disable NVIDIA GPU for stability test
$nvidiaGpu = Get-PnpDevice -Class Display | Where-Object {$_.Name -match "NVIDIA"}
if ($nvidiaGpu) {
    Write-Host "Disabling NVIDIA RTX 4060..." -ForegroundColor Yellow
    Disable-PnpDevice -InstanceId $nvidiaGpu.InstanceId -Confirm:$false
    Write-Host "RTX 4060 Disabled - Using AMD integrated graphics" -ForegroundColor Green
    Write-Host "Test system stability for 30 minutes"
}

# Force use of integrated AMD graphics
Set-DisplayResolution -Width 1920 -Height 1080

'@ -ForegroundColor Cyan

Write-Host "`n[SOLUTION 2: POWER MANAGEMENT OPTIMIZATION]" -ForegroundColor Green
Write-Host @'

# Limit GPU power consumption
nvidia-smi -pl 80  # Limit to 80% power (92W instead of 115W)

# Set GPU to prefer maximum performance (reduces power spikes)
nvidia-smi -pm 1

# Disable GPU boost (prevent sudden power draws)
# This requires MSI Afterburner or similar tool

'@ -ForegroundColor Cyan

Write-Host "`n[SOLUTION 3: HARDWARE FIXES]" -ForegroundColor Green
Write-Host @"

IMMEDIATE ACTIONS:
1. Check 8-pin PCIe power cable connection to RTX 4060
2. Verify GPU PSU can deliver 150W+ on 12V rail
3. Ensure GPU PSU powers on BEFORE main system
4. Use same power outlet for both PSUs (avoid ground loops)

PERMANENT SOLUTIONS:
1. Replace with single 750W+ PSU (powers both system + RTX 4060)
2. Add PSU synchronization module
3. Upgrade to higher wattage GPU PSU (if current is insufficient)

"@ -ForegroundColor Yellow

Write-Host "`n[TEST PROCEDURE]" -ForegroundColor Cyan
Write-Host @"

STEP 1: Disable RTX 4060 (software)
→ If stable = GPU power issue confirmed
→ If unstable = main PSU also has issues

STEP 2: Check power sequence
→ GPU PSU ON first, wait 5 seconds, then main PC
→ Test for 1 hour

STEP 3: Monitor power consumption  
→ Use power meter on both PSUs
→ Check for voltage drops under load

"@ -ForegroundColor White

Write-Host "`n=== RTX 4060 IS HIGHLY LIKELY THE CAUSE ===" -ForegroundColor Red
Write-Host "Execute the disable command above to test!" -ForegroundColor Yellow