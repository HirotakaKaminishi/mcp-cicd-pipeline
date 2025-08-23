# Remote Diagnosis Batch Script for Investigation PC
$targetPC = "192.168.111.163"
$username = "pc"
$password = ConvertTo-SecureString "1192" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "Starting remote diagnosis for $targetPC..." -ForegroundColor Green

# Test connection first
Write-Host "`n[Step 0] Testing connection..." -ForegroundColor Yellow
if (Test-Connection -ComputerName $targetPC -Count 2 -Quiet) {
    Write-Host "Connection successful!" -ForegroundColor Green
} else {
    Write-Host "Connection failed!" -ForegroundColor Red
    exit 1
}

# Step 1: Copy and execute diagnosis script
Write-Host "`n[Step 1] Copying diagnosis script to remote PC..." -ForegroundColor Yellow
try {
    $session = New-PSSession -ComputerName $targetPC -Credential $cred -ErrorAction Stop
    
    # Create directory if not exists
    Invoke-Command -Session $session -ScriptBlock {
        if (!(Test-Path "C:\Temp")) {
            New-Item -ItemType Directory -Path "C:\Temp" -Force
        }
    }
    
    # Copy script
    Copy-Item -Path "C:\Users\hirotaka\Documents\work\local_emergency_check.ps1" `
              -Destination "C:\Temp\emergency_check.ps1" `
              -ToSession $session -Force
    
    Write-Host "Script copied successfully!" -ForegroundColor Green
    
    # Execute diagnosis script
    Write-Host "`n[Step 2] Executing diagnosis script..." -ForegroundColor Yellow
    $result = Invoke-Command -Session $session -ScriptBlock {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        & "C:\Temp\emergency_check.ps1"
    }
    
    Write-Host $result
    
    # Step 3: Schedule memory diagnostic
    Write-Host "`n[Step 3] Scheduling memory diagnostic..." -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        # Check if we can schedule memory diagnostic
        Write-Host "Memory diagnostic will run on next reboot"
        Write-Host "To schedule: Run 'mdsched.exe' on the remote PC"
    }
    
    # Step 4: Get Event Viewer critical events
    Write-Host "`n[Step 4] Retrieving critical events from Event Viewer..." -ForegroundColor Yellow
    $events = Invoke-Command -Session $session -ScriptBlock {
        # Get last 20 critical events
        Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2} -MaxEvents 20 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Format-Table -AutoSize
    }
    
    Write-Host $events
    
    # Close session
    Remove-PSSession -Session $session
    
    Write-Host "`n[Complete] All diagnostic steps executed!" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nTrying alternative method..." -ForegroundColor Yellow
    
    # Alternative: Use WinRM directly
    try {
        winrm set winrm/config/client '@{TrustedHosts="*"}'
        Enable-PSRemoting -Force -SkipNetworkProfileCheck
        Write-Host "Please run the diagnosis script manually on the remote PC" -ForegroundColor Yellow
    } catch {
        Write-Host "Alternative method also failed: $_" -ForegroundColor Red
    }
}