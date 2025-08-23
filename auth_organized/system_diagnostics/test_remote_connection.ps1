# Test Remote Connection Script
# Tests connection to investigation PC (192.168.111.163)

$targetPC = "192.168.111.163"
$username = "pc"
$password = "1192"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing connection to Investigation PC" -ForegroundColor Yellow
Write-Host "Target: $targetPC" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Basic ping test
Write-Host "`n[1] Ping Test:" -ForegroundColor Green
$pingResult = Test-Connection -ComputerName $targetPC -Count 3 -Quiet
if ($pingResult) {
    Write-Host "✓ Ping successful - PC is online" -ForegroundColor Green
} else {
    Write-Host "✗ Ping failed - PC appears to be offline or unreachable" -ForegroundColor Red
    Write-Host "Investigation PC may have shut down again!" -ForegroundColor Yellow
    exit 1
}

# Step 2: Port check
Write-Host "`n[2] Checking Remote Management Ports:" -ForegroundColor Green
$ports = @(5985, 5986, 445, 135)  # WinRM HTTP, WinRM HTTPS, SMB, RPC
foreach ($port in $ports) {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $tcpClient.Connect($targetPC, $port)
        Write-Host "✓ Port $port is open" -ForegroundColor Green
        $tcpClient.Close()
    } catch {
        Write-Host "✗ Port $port is closed or filtered" -ForegroundColor Yellow
    }
}

# Step 3: Try WinRM connection
Write-Host "`n[3] Testing WinRM Connection:" -ForegroundColor Green
try {
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    
    $session = New-PSSession -ComputerName $targetPC -Credential $credential -ErrorAction Stop
    Write-Host "✓ WinRM connection successful!" -ForegroundColor Green
    
    # Get basic system info
    $systemInfo = Invoke-Command -Session $session -ScriptBlock {
        @{
            ComputerName = $env:COMPUTERNAME
            Username = $env:USERNAME
            Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        }
    }
    
    Write-Host "`n[4] Remote System Info:" -ForegroundColor Green
    Write-Host "Computer: $($systemInfo.ComputerName)" -ForegroundColor Cyan
    Write-Host "User: $($systemInfo.Username)" -ForegroundColor Cyan
    Write-Host "Uptime: $($systemInfo.Uptime.Days) days, $($systemInfo.Uptime.Hours) hours, $($systemInfo.Uptime.Minutes) minutes" -ForegroundColor Cyan
    
    Remove-PSSession -Session $session
    
} catch {
    Write-Host "✗ WinRM connection failed: $_" -ForegroundColor Red
    Write-Host "`nPossible issues:" -ForegroundColor Yellow
    Write-Host "1. WinRM service not running on remote PC" -ForegroundColor Yellow
    Write-Host "2. Firewall blocking connection" -ForegroundColor Yellow
    Write-Host "3. Credentials incorrect" -ForegroundColor Yellow
    Write-Host "4. Remote PC not configured for remote management" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Connection test complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan