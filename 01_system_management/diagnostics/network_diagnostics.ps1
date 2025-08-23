# Network Connectivity Diagnostics for 192.168.111.163
# When PC is online but ping fails

$targetPC = "192.168.111.163"
$username = "pc"
$password = "1192"

Write-Host "=== NETWORK CONNECTIVITY DIAGNOSTICS ===" -ForegroundColor Cyan
Write-Host "Target: $targetPC (Online but Ping fails)" -ForegroundColor Yellow

# Test various connection methods
Write-Host "`n[1] Testing different protocols..." -ForegroundColor Green

# Test SMB (port 445)
Write-Host "Testing SMB connection (port 445)..." -ForegroundColor Yellow
try {
    $smb = Test-NetConnection -ComputerName $targetPC -Port 445 -InformationLevel Quiet
    if ($smb) {
        Write-Host "✓ SMB (445) - Connected" -ForegroundColor Green
    } else {
        Write-Host "✗ SMB (445) - Failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ SMB test error: $_" -ForegroundColor Red
}

# Test WinRM HTTP (port 5985)
Write-Host "Testing WinRM HTTP (port 5985)..." -ForegroundColor Yellow
try {
    $winrm = Test-NetConnection -ComputerName $targetPC -Port 5985 -InformationLevel Quiet
    if ($winrm) {
        Write-Host "✓ WinRM HTTP (5985) - Connected" -ForegroundColor Green
    } else {
        Write-Host "✗ WinRM HTTP (5985) - Failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ WinRM test error: $_" -ForegroundColor Red
}

# Test WinRM HTTPS (port 5986)
Write-Host "Testing WinRM HTTPS (port 5986)..." -ForegroundColor Yellow
try {
    $winrms = Test-NetConnection -ComputerName $targetPC -Port 5986 -InformationLevel Quiet
    if ($winrms) {
        Write-Host "✓ WinRM HTTPS (5986) - Connected" -ForegroundColor Green
    } else {
        Write-Host "✗ WinRM HTTPS (5986) - Failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ WinRM HTTPS test error: $_" -ForegroundColor Red
}

# Test RDP (port 3389)
Write-Host "Testing RDP (port 3389)..." -ForegroundColor Yellow
try {
    $rdp = Test-NetConnection -ComputerName $targetPC -Port 3389 -InformationLevel Quiet
    if ($rdp) {
        Write-Host "✓ RDP (3389) - Connected" -ForegroundColor Green
    } else {
        Write-Host "✗ RDP (3389) - Failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ RDP test error: $_" -ForegroundColor Red
}

# Try different ping methods
Write-Host "`n[2] Testing different ping methods..." -ForegroundColor Green

# Standard ping
Write-Host "Standard ping test..." -ForegroundColor Yellow
$ping1 = Test-Connection -ComputerName $targetPC -Count 1 -Quiet
Write-Host "Standard ping: $(if($ping1){'✓ Success'}else{'✗ Failed'})" -ForegroundColor $(if($ping1){'Green'}else{'Red'})

# Force IPv4
Write-Host "IPv4 ping test..." -ForegroundColor Yellow
try {
    $ping2 = Test-Connection -ComputerName $targetPC -Count 1 -IPv4 -Quiet
    Write-Host "IPv4 ping: $(if($ping2){'✓ Success'}else{'✗ Failed'})" -ForegroundColor $(if($ping2){'Green'}else{'Red'})
} catch {
    Write-Host "IPv4 ping: ✗ Failed - $_" -ForegroundColor Red
}

# Try with timeout
Write-Host "Ping with extended timeout..." -ForegroundColor Yellow
try {
    $ping3 = Test-Connection -ComputerName $targetPC -Count 1 -TimeoutSeconds 10 -Quiet
    Write-Host "Extended timeout ping: $(if($ping3){'✓ Success'}else{'✗ Failed'})" -ForegroundColor $(if($ping3){'Green'}else{'Red'})
} catch {
    Write-Host "Extended timeout ping: ✗ Failed - $_" -ForegroundColor Red
}

# Direct PowerShell Remoting attempt
Write-Host "`n[3] Attempting PowerShell Remoting..." -ForegroundColor Green
try {
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    
    Write-Host "Trying to establish PS session..." -ForegroundColor Yellow
    $session = New-PSSession -ComputerName $targetPC -Credential $credential -ErrorAction Stop
    
    Write-Host "✓ PowerShell session established!" -ForegroundColor Green
    
    # If successful, run immediate diagnostics
    Write-Host "`n[4] Running immediate system check..." -ForegroundColor Green
    $result = Invoke-Command -Session $session -ScriptBlock {
        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $firewall = Get-NetFirewallProfile | Where-Object {$_.Enabled -eq $true} | Select-Object Name
        $ping_settings = Get-NetFirewallRule -DisplayName "*ping*" -ErrorAction SilentlyContinue | Select-Object DisplayName, Enabled
        
        @{
            ComputerName = $env:COMPUTERNAME
            CurrentUser = $env:USERNAME
            Uptime = "$($uptime.Hours)h $($uptime.Minutes)m"
            FirewallProfiles = ($firewall.Name -join ", ")
            PingRules = $ping_settings
        }
    }
    
    Write-Host "Computer: $($result.ComputerName)" -ForegroundColor Cyan
    Write-Host "User: $($result.CurrentUser)" -ForegroundColor Cyan
    Write-Host "Uptime: $($result.Uptime)" -ForegroundColor Cyan
    Write-Host "Active Firewall: $($result.FirewallProfiles)" -ForegroundColor Cyan
    
    # Schedule memory test immediately
    Write-Host "`n[5] Scheduling memory diagnostic..." -ForegroundColor Green
    $memTest = Invoke-Command -Session $session -ScriptBlock {
        try {
            mdsched.exe /t
            return "✓ Memory test scheduled for immediate reboot"
        } catch {
            return "✗ Failed to schedule memory test: $_"
        }
    }
    Write-Host $memTest -ForegroundColor $(if($memTest -match "✓"){'Green'}else{'Red'})
    
    # Apply emergency power settings
    Write-Host "`n[6] Applying emergency power settings..." -ForegroundColor Green
    Invoke-Command -Session $session -ScriptBlock {
        # Power saver mode
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a
        
        # CPU throttle to 60%
        powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 60
        powercfg /setactive scheme_current
        
        Write-Host "✓ Emergency power settings applied"
    }
    
    Remove-PSSession -Session $session
    
    Write-Host "`n✓ DIAGNOSTICS COMPLETE - Reboot required for memory test" -ForegroundColor Green
    
} catch {
    Write-Host "✗ PowerShell remoting failed: $_" -ForegroundColor Red
    
    Write-Host "`n[Alternative] Manual steps for the PC:" -ForegroundColor Yellow
    Write-Host "1. Run as Administrator: mdsched.exe" -ForegroundColor Cyan
    Write-Host "2. Select 'Restart now and check for problems'" -ForegroundColor Cyan
    Write-Host "3. PC will reboot and run memory test" -ForegroundColor Cyan
    Write-Host "4. Check results in Event Viewer after test" -ForegroundColor Cyan
}

Write-Host "`n=== NETWORK DIAGNOSTICS COMPLETE ===" -ForegroundColor Cyan