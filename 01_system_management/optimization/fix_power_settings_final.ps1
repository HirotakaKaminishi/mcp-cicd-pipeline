# Fix Power Settings - Final Configuration
Write-Host "=== FIXING CRITICAL POWER SETTINGS ===" -ForegroundColor Red
Write-Host "Current settings are causing power issues!" -ForegroundColor Yellow

Write-Host "`n[CURRENT PROBLEMS]" -ForegroundColor Red
Write-Host @"
1. Power plan reverted to 'Balanced' (should be High Performance)
2. Min CPU at 80% (way too high - causes constant high power draw)
3. Max CPU at 80% (limited but still high)
4. This configuration causes unnecessary power consumption!
"@ -ForegroundColor Yellow

Write-Host "`n[APPLYING OPTIMAL SETTINGS]" -ForegroundColor Green

# Switch to High Performance plan
Write-Host "1. Switching to High Performance plan..." -ForegroundColor Cyan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Set reasonable CPU limits
Write-Host "2. Setting CPU to reasonable limits..." -ForegroundColor Cyan
# Minimum CPU to 5% (allows proper idle)
powercfg /setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 5
# Maximum CPU to 100% (allow full performance when needed)
powercfg /setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100

# Disable processor idle states
Write-Host "3. Disabling C-states..." -ForegroundColor Cyan
powercfg /setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 5d76a2ca-e8c0-402f-a133-2158492d58ad 1

# Disable processor parking
Write-Host "4. Disabling processor parking..." -ForegroundColor Cyan
powercfg /setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0

# Apply the settings
Write-Host "5. Applying all settings..." -ForegroundColor Cyan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

Write-Host "`n[VERIFICATION]" -ForegroundColor Green
$currentPlan = powercfg /getactivescheme
Write-Host "Active plan: $currentPlan" -ForegroundColor Cyan

# Show current settings
Write-Host "`nCurrent processor settings:" -ForegroundColor Yellow
powercfg /query 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 | Select-String "最小|最大|現在"

Write-Host "`n[ALTERNATIVE: SAFER POWER SETTINGS]" -ForegroundColor Yellow
Write-Host @'

If system is still unstable, try these CONSERVATIVE settings:

# Create custom power plan with lower limits
powercfg /duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e >nul
# Set to the new custom plan (get GUID from above command)
# Then apply these settings:

# Min CPU 5%, Max CPU 70% (reduce power draw)
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 5
powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 70

# Disable turbo boost
powercfg /setacvalueindex scheme_current sub_processor PERFBOOSTMODE 0

# Apply
powercfg /setactive scheme_current

'@ -ForegroundColor Cyan

Write-Host "`n[MONITORING COMMANDS]" -ForegroundColor Green
Write-Host @'

# Monitor CPU frequency
Get-WmiObject Win32_Processor | Select-Object Name, CurrentClockSpeed, MaxClockSpeed

# Monitor power consumption
Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 5 -MaxSamples 10

# Check for throttling
Get-Counter "\Processor Information(_Total)\% Processor Performance" -SampleInterval 5 -MaxSamples 10

'@ -ForegroundColor White

Write-Host "`n=== POWER SETTINGS FIXED ===" -ForegroundColor Green
Write-Host "Key changes:" -ForegroundColor Yellow
Write-Host "- High Performance mode active" -ForegroundColor Green
Write-Host "- CPU Min reduced from 80% to 5% (massive power saving)" -ForegroundColor Green
Write-Host "- CPU Max set to 100% (full performance available)" -ForegroundColor Green
Write-Host "- C-states disabled (prevents random shutdowns)" -ForegroundColor Green

Write-Host "`nTest system stability for 30 minutes!" -ForegroundColor Cyan