# Simple Connection Test for 192.168.111.163
$targetPC = "192.168.111.163"
$username = "pc"
$password = "1192"

Write-Host "=== SIMPLE CONNECTION TEST ===" -ForegroundColor Green
Write-Host "Target: $targetPC" -ForegroundColor Yellow

# Test ports
$ports = @(445, 5985, 3389)
foreach ($port in $ports) {
    try {
        $test = Test-NetConnection -ComputerName $targetPC -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Host "Port $port : $(if($test){'Open'}else{'Closed'})" -ForegroundColor $(if($test){'Green'}else{'Red'})
    } catch {
        Write-Host "Port $port : Error" -ForegroundColor Red
    }
}

# Try PowerShell Remoting
Write-Host "`nTesting PowerShell Remoting..." -ForegroundColor Yellow
try {
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    
    $session = New-PSSession -ComputerName $targetPC -Credential $credential -ErrorAction Stop
    Write-Host "PowerShell Remoting: SUCCESS" -ForegroundColor Green
    
    # Execute memory test
    Write-Host "`nScheduling memory test..." -ForegroundColor Yellow
    $result = Invoke-Command -Session $session -ScriptBlock {
        mdsched.exe /t
        return "Memory test scheduled"
    }
    Write-Host $result -ForegroundColor Green
    
    Remove-PSSession -Session $session
    
} catch {
    Write-Host "PowerShell Remoting: FAILED - $_" -ForegroundColor Red
}