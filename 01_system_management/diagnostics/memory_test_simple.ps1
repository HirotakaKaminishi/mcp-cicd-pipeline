# Simple Memory Test Execution
$targetPC = "192.168.111.163"
$username = "pc"
$password = ConvertTo-SecureString "1192" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "=== MEMORY TEST EXECUTION ===" -ForegroundColor Red

try {
    $session = New-PSSession -ComputerName $targetPC -Credential $credential -ErrorAction Stop
    Write-Host "Connected to $targetPC" -ForegroundColor Green
    
    # Schedule memory test
    Write-Host "Scheduling memory diagnostic..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        mdsched.exe /t
        Write-Host "Memory test scheduled for next reboot" -ForegroundColor Green
    }
    
    # Apply power saving
    Write-Host "Applying power limits..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 60
        powercfg /setactive scheme_current
        Write-Host "CPU limited to 60%" -ForegroundColor Green
    }
    
    # Get status
    Write-Host "System status:" -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Write-Host "Uptime: $($uptime.Hours)h $($uptime.Minutes)m"
    }
    
    Remove-PSSession -Session $session
    Write-Host "`nREADY: Reboot PC to run memory test" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}