# Memory Test Results Checker
# メモリテスト結果確認スクリプト

Write-Host "=== MEMORY TEST RESULTS CHECKER ===" -ForegroundColor Green
Write-Host "Checking memory diagnostic results..." -ForegroundColor Yellow

# 1. Check if memory test has been run
Write-Host "`n[1] Searching for Memory Diagnostic Results..." -ForegroundColor Cyan

try {
    # Get memory diagnostic results
    $memResults = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ProviderName = 'Microsoft-Windows-MemoryDiagnostics-Results'
    } -MaxEvents 5 -ErrorAction SilentlyContinue
    
    if ($memResults) {
        Write-Host "`n✓ Memory test results found!" -ForegroundColor Green
        
        foreach ($event in $memResults) {
            Write-Host "`n------------------------" -ForegroundColor Yellow
            Write-Host "Test Date: $($event.TimeCreated)" -ForegroundColor Cyan
            Write-Host "Event ID: $($event.Id)" -ForegroundColor Cyan
            
            # Parse the message for results
            $message = $event.Message
            
            if ($message -match "no errors") {
                Write-Host "Result: ✓ NO ERRORS DETECTED" -ForegroundColor Green
                Write-Host "Status: Memory is functioning correctly" -ForegroundColor Green
            } elseif ($message -match "detected") {
                Write-Host "Result: ✗ ERRORS DETECTED" -ForegroundColor Red
                Write-Host "Status: Memory problems found - replacement recommended" -ForegroundColor Red
            } else {
                Write-Host "Result: Test completed" -ForegroundColor Yellow
            }
            
            Write-Host "`nFull Message:" -ForegroundColor Gray
            Write-Host $message -ForegroundColor White
        }
        
    } else {
        Write-Host "`n⚠ No memory test results found" -ForegroundColor Yellow
        Write-Host "Memory test may not have been run yet, or results not available" -ForegroundColor Yellow
        
        # Check for scheduled test
        Write-Host "`n[2] Checking for scheduled memory test..." -ForegroundColor Cyan
        $scheduledTasks = Get-ScheduledTask -TaskName "*Memory*" -ErrorAction SilentlyContinue
        if ($scheduledTasks) {
            Write-Host "Scheduled memory tasks found:" -ForegroundColor Cyan
            $scheduledTasks | Format-Table TaskName, State
        }
        
        Write-Host "`n[How to run memory test]" -ForegroundColor Yellow
        Write-Host "1. Open Command Prompt as Administrator" -ForegroundColor White
        Write-Host "2. Run: mdsched.exe" -ForegroundColor White
        Write-Host "3. Select 'Restart now and check for problems'" -ForegroundColor White
        Write-Host "4. PC will restart and run memory test (10-30 minutes)" -ForegroundColor White
        Write-Host "5. After completion, run this script again to see results" -ForegroundColor White
    }
    
} catch {
    Write-Host "Error checking results: $_" -ForegroundColor Red
}

# 2. Check system health related to memory
Write-Host "`n[2] System Memory Status:" -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem
$comp = Get-CimInstance Win32_ComputerSystem
$memModules = Get-CimInstance Win32_PhysicalMemory

Write-Host "Total Physical Memory: $([math]::Round($comp.TotalPhysicalMemory/1GB, 2)) GB" -ForegroundColor White
Write-Host "Available Memory: $([math]::Round($os.FreePhysicalMemory/1MB, 2)) GB" -ForegroundColor White
Write-Host "Memory Usage: $([math]::Round((($comp.TotalPhysicalMemory/1GB) - ($os.FreePhysicalMemory/1KB/1GB))/($comp.TotalPhysicalMemory/1GB)*100, 1))%" -ForegroundColor White

Write-Host "`n[3] Installed Memory Modules:" -ForegroundColor Cyan
foreach ($module in $memModules) {
    Write-Host "`nSlot: $($module.DeviceLocator)" -ForegroundColor Yellow
    Write-Host "  Capacity: $([math]::Round($module.Capacity/1GB, 2)) GB" -ForegroundColor White
    Write-Host "  Speed: $($module.Speed) MHz" -ForegroundColor White
    Write-Host "  Manufacturer: $($module.Manufacturer)" -ForegroundColor White
    Write-Host "  Part Number: $($module.PartNumber)" -ForegroundColor White
}

# 3. Check for memory-related errors
Write-Host "`n[4] Recent Memory-Related Errors:" -ForegroundColor Cyan

$memErrors = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Level = 2,3  # Warning and Error
} -MaxEvents 100 -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -match "memory|Memory|RAM|paged pool|nonpaged"
}

if ($memErrors) {
    Write-Host "Found $($memErrors.Count) memory-related warnings/errors:" -ForegroundColor Yellow
    $memErrors | Select-Object -First 5 | Format-Table TimeCreated, LevelDisplayName, Message -AutoSize
} else {
    Write-Host "✓ No recent memory-related errors found" -ForegroundColor Green
}

# 4. Check WHEA errors (hardware errors)
Write-Host "`n[5] Hardware Error Events (WHEA):" -ForegroundColor Cyan

$wheaErrors = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'Microsoft-Windows-WHEA-Logger'
} -MaxEvents 10 -ErrorAction SilentlyContinue

if ($wheaErrors) {
    Write-Host "⚠ Found $($wheaErrors.Count) hardware error events:" -ForegroundColor Red
    $wheaErrors | Select-Object -First 5 | Format-Table TimeCreated, Id, Message -AutoSize
} else {
    Write-Host "✓ No hardware error events found" -ForegroundColor Green
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Green

if ($memResults -and $memResults[0].Message -match "no errors") {
    Write-Host "✓ Memory test passed - No errors detected" -ForegroundColor Green
    Write-Host "✓ Memory modules appear to be functioning correctly" -ForegroundColor Green
} elseif ($memResults -and $memResults[0].Message -match "detected") {
    Write-Host "✗ Memory test failed - Errors detected" -ForegroundColor Red
    Write-Host "⚠ Recommend replacing faulty memory modules" -ForegroundColor Red
    Write-Host "⚠ This could be causing the unexpected shutdowns" -ForegroundColor Red
} else {
    Write-Host "⚠ Memory test results not available" -ForegroundColor Yellow
    Write-Host "→ Run 'mdsched.exe' to perform memory diagnostic" -ForegroundColor Yellow
}

Write-Host "`n=== END OF DIAGNOSTIC ===" -ForegroundColor Cyan