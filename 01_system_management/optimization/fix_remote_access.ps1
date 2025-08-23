# Fix Remote Access Issues
# Run this on the LOCAL machine (192.168.111.200) to connect to 192.168.111.163

Write-Host "=== FIXING REMOTE ACCESS ===" -ForegroundColor Yellow
Write-Host "Attempting to resolve access denied issue" -ForegroundColor Cyan

# Step 1: Configure local settings
Write-Host "`n[1] Configuring local WinRM settings..." -ForegroundColor Green
try {
    # Trust the remote host
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.111.163" -Force
    
    # Enable WinRM if not already
    Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction SilentlyContinue
    
    # Set authentication
    Set-Item WSMan:\localhost\Client\AllowUnencrypted -Value $true -Force
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
    
    Write-Host "✓ Local settings configured" -ForegroundColor Green
} catch {
    Write-Host "✗ Error configuring local settings: $_" -ForegroundColor Red
}

# Step 2: Test different authentication methods
Write-Host "`n[2] Testing connection methods..." -ForegroundColor Green

$targetPC = "192.168.111.163"
$username = "pc"
$password = "1192"

# Method 1: Basic authentication
Write-Host "Testing basic authentication..." -ForegroundColor Yellow
try {
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("$targetPC\$username", $securePassword)
    
    $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    $session = New-PSSession -ComputerName $targetPC -Credential $credential -SessionOption $sessionOption -Authentication Basic -ErrorAction Stop
    
    Write-Host "✓ Basic auth successful!" -ForegroundColor Green
    Remove-PSSession -Session $session
} catch {
    Write-Host "✗ Basic auth failed: $_" -ForegroundColor Red
}

# Method 2: Negotiate authentication
Write-Host "Testing negotiate authentication..." -ForegroundColor Yellow
try {
    $credential2 = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    $session2 = New-PSSession -ComputerName $targetPC -Credential $credential2 -Authentication Negotiate -ErrorAction Stop
    
    Write-Host "✓ Negotiate auth successful!" -ForegroundColor Green
    Remove-PSSession -Session $session2
} catch {
    Write-Host "✗ Negotiate auth failed: $_" -ForegroundColor Red
}

# Method 3: Direct WinRM test
Write-Host "`n[3] Direct WinRM test..." -ForegroundColor Green
Write-Host "Testing WinRM directly..." -ForegroundColor Yellow
try {
    winrm id -r:$targetPC -u:$username -p:$password 2>&1 | Out-String
    Write-Host "✓ Direct WinRM successful!" -ForegroundColor Green
} catch {
    Write-Host "✗ Direct WinRM failed" -ForegroundColor Red
}

Write-Host "`n=== TROUBLESHOOTING GUIDE ===" -ForegroundColor Cyan
Write-Host @"

If all methods failed, run these commands ON THE REMOTE PC (192.168.111.163):

1. Enable PowerShell Remoting:
   Enable-PSRemoting -Force -SkipNetworkProfileCheck
   
2. Configure WinRM service:
   winrm quickconfig -Force
   
3. Allow unencrypted traffic (for testing):
   winrm set winrm/config/service '@{AllowUnencrypted="true"}'
   winrm set winrm/config/service/auth '@{Basic="true"}'
   
4. Add trusted hosts:
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.111.200" -Force
   
5. Check firewall:
   New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "WinRM-HTTP" -Protocol TCP -LocalPort 5985 -Action Allow
   
6. Restart WinRM:
   Restart-Service WinRM

7. Verify user is in Administrators group:
   net localgroup Administrators

"@ -ForegroundColor Yellow