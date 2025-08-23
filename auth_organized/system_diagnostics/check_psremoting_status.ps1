# PowerShell Remoting状態確認スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "======================================" -ForegroundColor Green
Write-Host "  PowerShell Remoting Status Check" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target: $targetPC" -ForegroundColor Cyan

function Test-PSRemotingStatus {
    param($computerName, $credential)
    
    try {
        # WinRM サービス状態確認
        Write-Host "`n1. Testing WinRM connectivity..." -ForegroundColor Yellow
        $winrmTest = Test-WSMan -ComputerName $computerName -ErrorAction SilentlyContinue
        
        if ($winrmTest) {
            Write-Host "   WinRM Service: ACCESSIBLE" -ForegroundColor Green
            Write-Host "   Protocol Version: $($winrmTest.ProductVersion)" -ForegroundColor White
        } else {
            Write-Host "   WinRM Service: NOT ACCESSIBLE" -ForegroundColor Red
            return $false
        }
        
        # PowerShell Remoting テスト
        Write-Host "`n2. Testing PowerShell Remoting..." -ForegroundColor Yellow
        $remoteTest = Invoke-Command -ComputerName $computerName -Credential $credential -ScriptBlock {
            return @{
                ComputerName = $env:COMPUTERNAME
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                ExecutionPolicy = Get-ExecutionPolicy
                WinRMService = (Get-Service -Name WinRM).Status
                CurrentUser = $env:USERNAME
                TestTime = Get-Date
            }
        } -ErrorAction Stop
        
        Write-Host "   PowerShell Remoting: WORKING" -ForegroundColor Green
        Write-Host "   Remote Computer: $($remoteTest.ComputerName)" -ForegroundColor White
        Write-Host "   PowerShell Version: $($remoteTest.PowerShellVersion)" -ForegroundColor White
        Write-Host "   Execution Policy: $($remoteTest.ExecutionPolicy)" -ForegroundColor White
        Write-Host "   WinRM Service: $($remoteTest.WinRMService)" -ForegroundColor White
        Write-Host "   Current User: $($remoteTest.CurrentUser)" -ForegroundColor White
        Write-Host "   Remote Time: $($remoteTest.TestTime)" -ForegroundColor White
        
        return $true
        
    } catch {
        Write-Host "   PowerShell Remoting: FAILED" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# 接続状態を複数回チェック
$maxAttempts = 15
$attemptDelay = 20  # 20秒間隔

Write-Host "`nAttempting to connect (max $maxAttempts attempts, $attemptDelay second intervals)..." -ForegroundColor Yellow

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    Write-Host "`n--- Attempt $attempt/$maxAttempts ---" -ForegroundColor Cyan
    
    # ネットワーク接続確認
    $pingResult = Test-Connection -ComputerName $targetPC -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($pingResult) {
        Write-Host "Network connectivity: ONLINE" -ForegroundColor Green
        
        # PowerShell Remoting テスト
        $psRemotingWorking = Test-PSRemotingStatus -computerName $targetPC -credential $cred
        
        if ($psRemotingWorking) {
            Write-Host "`n🎉 SUCCESS: PowerShell Remoting is WORKING!" -ForegroundColor Green
            
            # 詳細な WinRM 設定確認
            Write-Host "`n3. Checking detailed WinRM configuration..." -ForegroundColor Yellow
            
            try {
                $winrmConfig = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
                    $config = @{}
                    
                    # WinRM サービス詳細
                    $winrmService = Get-Service -Name WinRM
                    $config.WinRMServiceStatus = $winrmService.Status
                    $config.WinRMServiceStartType = $winrmService.StartType
                    
                    # WinRM リスナー確認
                    try {
                        $listeners = winrm enumerate winrm/config/listener
                        $config.WinRMListeners = $listeners
                    } catch {
                        $config.WinRMListeners = "Could not enumerate listeners"
                    }
                    
                    # TrustedHosts 確認
                    try {
                        $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
                        $config.TrustedHosts = $trustedHosts.Value
                    } catch {
                        $config.TrustedHosts = "Not accessible"
                    }
                    
                    # ファイアウォール状態
                    try {
                        $firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled
                        $config.FirewallProfiles = $firewallProfiles
                    } catch {
                        $config.FirewallProfiles = "Could not check firewall"
                    }
                    
                    return $config
                }
                
                Write-Host "`nDetailed WinRM Configuration:" -ForegroundColor Cyan
                Write-Host "   Service Status: $($winrmConfig.WinRMServiceStatus)" -ForegroundColor White
                Write-Host "   Service Start Type: $($winrmConfig.WinRMServiceStartType)" -ForegroundColor White
                Write-Host "   TrustedHosts: $($winrmConfig.TrustedHosts)" -ForegroundColor White
                
                if ($winrmConfig.FirewallProfiles) {
                    Write-Host "   Firewall Profiles:" -ForegroundColor White
                    foreach ($profile in $winrmConfig.FirewallProfiles) {
                        $status = if ($profile.Enabled) { "Enabled" } else { "Disabled" }
                        Write-Host "     $($profile.Name): $status" -ForegroundColor Gray
                    }
                }
                
            } catch {
                Write-Host "   Could not retrieve detailed configuration: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            break
        }
        
    } else {
        Write-Host "Network connectivity: OFFLINE" -ForegroundColor Red
    }
    
    if ($attempt -lt $maxAttempts) {
        Write-Host "   Waiting $attemptDelay seconds before next attempt..." -ForegroundColor Gray
        Start-Sleep -Seconds $attemptDelay
    }
}

if ($attempt -gt $maxAttempts) {
    Write-Host "`n❌ TIMEOUT: Could not establish PowerShell Remoting after $maxAttempts attempts" -ForegroundColor Red
    Write-Host "`nPossible issues and solutions:" -ForegroundColor Yellow
    Write-Host "1. System is still booting - wait longer and retry" -ForegroundColor White
    Write-Host "2. WinRM service disabled after restart:" -ForegroundColor White
    Write-Host "   - Log in locally to the target PC" -ForegroundColor Gray
    Write-Host "   - Run: Enable-PSRemoting -Force" -ForegroundColor Gray
    Write-Host "   - Run: Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force" -ForegroundColor Gray
    Write-Host "3. Network/Firewall issues:" -ForegroundColor White
    Write-Host "   - Check network connectivity" -ForegroundColor Gray
    Write-Host "   - Verify firewall settings" -ForegroundColor Gray
    Write-Host "4. User account/authentication issues:" -ForegroundColor White
    Write-Host "   - Verify user account is still valid" -ForegroundColor Gray
    Write-Host "   - Check if password needs to be reset" -ForegroundColor Gray
} else {
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "    PowerShell Remoting Status: WORKING" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green
}

Read-Host "`nPress Enter to continue"