# Disable AMD C6 Power State
# AMD C6 can cause unexpected shutdowns on Ryzen systems

Write-Host "=== DISABLING AMD C6 POWER STATE ===" -ForegroundColor Red
Write-Host "This may resolve random shutdown issues on Ryzen systems" -ForegroundColor Yellow

Write-Host "`n[METHOD 1: PowerShell Registry Method]" -ForegroundColor Green
Write-Host "Disabling C6 via Windows Registry..." -ForegroundColor Cyan

try {
    # Disable C6 state in Windows power management
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    
    # Set C6 disable flag
    Set-ItemProperty -Path $regPath -Name "CsEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $regPath -Name "CustomizeDuringSetup" -Value 1 -Type DWord -Force
    
    # Disable processor idle states
    $procPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\5d76a2ca-e8c0-402f-a133-2158492d58ad"
    if (Test-Path $procPath) {
        Set-ItemProperty -Path $procPath -Name "ACSettingIndex" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $procPath -Name "DCSettingIndex" -Value 1 -Type DWord -Force
    }
    
    Write-Host "✓ Registry C6 disable completed" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Registry method failed: $_" -ForegroundColor Red
}

Write-Host "`n[METHOD 2: PowerCfg Command Method]" -ForegroundColor Green
Write-Host "Using powercfg to disable processor idle states..." -ForegroundColor Cyan

try {
    # Disable processor idle states completely
    powercfg /setacvalueindex scheme_current sub_processor PROCESSORIDLEDISABLE 1
    powercfg /setdcvalueindex scheme_current sub_processor PROCESSORIDLEDISABLE 1
    
    # Set processor idle threshold to maximum (prevent deep sleep)
    powercfg /setacvalueindex scheme_current sub_processor PROCESSORIDLETHRESHOLD 100
    powercfg /setdcvalueindex scheme_current sub_processor PROCESSORIDLETHRESHOLD 100
    
    # Disable selective suspend for processors
    powercfg /setacvalueindex scheme_current sub_processor PROCESSORIDLEDEMOTE 0
    powercfg /setdcvalueindex scheme_current sub_processor PROCESSORIDLEDEMOTE 0
    
    # Apply settings
    powercfg /setactive scheme_current
    
    Write-Host "✓ PowerCfg C6 disable completed" -ForegroundColor Green
    
} catch {
    Write-Host "✗ PowerCfg method failed: $_" -ForegroundColor Red
}

Write-Host "`n[METHOD 3: High Performance Power Plan]" -ForegroundColor Green
Write-Host "Switching to High Performance mode..." -ForegroundColor Cyan

try {
    # Set High Performance power plan
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    
    # Verify current plan
    $currentPlan = powercfg /getactivescheme
    Write-Host "Current plan: $currentPlan" -ForegroundColor Cyan
    
    Write-Host "✓ High Performance mode enabled" -ForegroundColor Green
    
} catch {
    Write-Host "✗ High Performance method failed: $_" -ForegroundColor Red
}

Write-Host "`n[METHOD 4: Manual Registry Entries]" -ForegroundColor Green
Write-Host @'

# Advanced registry modifications (run as Administrator):

# Disable all processor C-states
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "CsEnabled" /t REG_DWORD /d 0 /f

# Disable AMD-specific power features
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DisableVSyncOffload" /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "EventProcessorEnabled" /t REG_DWORD /d 0 /f

# Disable processor parking
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v "ACSettingIndex" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v "DCSettingIndex" /t REG_DWORD /d 0 /f

'@ -ForegroundColor Yellow

Write-Host "`n[VERIFICATION COMMANDS]" -ForegroundColor Cyan
Write-Host @'

# Check current processor power settings
powercfg /query scheme_current sub_processor

# Check C-state status
powercfg /energy /duration 10

# Monitor CPU states
Get-Counter "\Processor Information(_Total)\% C1 Time" -SampleInterval 5 -MaxSamples 5
Get-Counter "\Processor Information(_Total)\% C2 Time" -SampleInterval 5 -MaxSamples 5
Get-Counter "\Processor Information(_Total)\% C3 Time" -SampleInterval 5 -MaxSamples 5

'@ -ForegroundColor White

Write-Host "`n[BIOS SETTINGS TO DISABLE]" -ForegroundColor Red
Write-Host @"

If Windows methods don't work, disable in BIOS:

1. Boot to BIOS/UEFI setup
2. Navigate to: Advanced → CPU Configuration
3. Disable these settings:
   - C6 State Support: Disabled
   - Package C State Support: Disabled  
   - Core C State Support: Disabled
   - AMD Cool'n'Quiet: Disabled
   - Global C-state Control: Disabled

4. Power Management settings:
   - ACPI S3 Support: Disabled
   - ACPI S4 Support: Disabled
   - ErP Ready: Disabled

5. Save and Exit

"@ -ForegroundColor Yellow

Write-Host "`n[RESTART REQUIRED]" -ForegroundColor Red
Write-Host "System restart required for C6 disable to take effect!" -ForegroundColor Yellow
Write-Host "After restart, test system stability for 1 hour" -ForegroundColor Cyan

Write-Host "`n=== C6 DISABLE PROCESS COMPLETE ===" -ForegroundColor Green
Write-Host "This should prevent C6-related random shutdowns" -ForegroundColor Cyan