# 修正版：既存ユーザー「pc」での接続テスト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "=== Testing Connection with User 'pc' (Fixed) ===" -ForegroundColor Green
Write-Host "Target PC: $targetPC" -ForegroundColor Cyan
Write-Host "Username: $username" -ForegroundColor Cyan

try {
    # 認証情報作成
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    
    Write-Host "`n1. Testing basic connection..." -ForegroundColor Yellow
    $testResult = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        # グループ情報を安全に取得
        $groupInfo = try {
            $groups = whoami /groups 2>$null
            if ($groups) { "Groups retrieved successfully" } else { "Groups not available" }
        } catch {
            "Groups not available"
        }
        
        @{
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            IsAdmin = $isAdmin
            DateTime = Get-Date
            GroupInfo = $groupInfo
        }
    } -ErrorAction Stop
    
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host "Computer: $($testResult.ComputerName)" -ForegroundColor White
    Write-Host "Connected as: $($testResult.UserName)" -ForegroundColor White
    Write-Host "Admin privileges: $($testResult.IsAdmin)" -ForegroundColor White
    Write-Host "Time: $($testResult.DateTime)" -ForegroundColor White
    Write-Host "Groups: $($testResult.GroupInfo)" -ForegroundColor White
    
    if ($testResult.IsAdmin) {
        Write-Host "`n2. Testing administrative capabilities..." -ForegroundColor Yellow
        
        # Event Logアクセステスト
        $adminTests = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            $results = @{}
            
            # Event Log テスト
            try {
                $events = Get-EventLog -LogName System -Newest 3 -ErrorAction Stop
                $results.EventLog = "SUCCESS: Retrieved $($events.Count) events"
            } catch {
                $results.EventLog = "FAILED: $($_.Exception.Message)"
            }
            
            # WMI テスト
            try {
                $system = Get-WmiObject Win32_ComputerSystem -ErrorAction Stop
                $results.WMI = "SUCCESS: $($system.Manufacturer) $($system.Model)"
            } catch {
                $results.WMI = "FAILED: $($_.Exception.Message)"
            }
            
            # PowerCfg テスト
            try {
                $powerInfo = powercfg /list 2>$null
                if ($powerInfo) {
                    $results.PowerCfg = "SUCCESS: Power configuration accessible"
                } else {
                    $results.PowerCfg = "FAILED: PowerCfg not accessible"
                }
            } catch {
                $results.PowerCfg = "FAILED: $($_.Exception.Message)"
            }
            
            return $results
        }
        
        Write-Host "Test Results:" -ForegroundColor Cyan
        Write-Host "  Event Log: $($adminTests.EventLog)" -ForegroundColor White
        Write-Host "  WMI Access: $($adminTests.WMI)" -ForegroundColor White
        Write-Host "  PowerCfg: $($adminTests.PowerCfg)" -ForegroundColor White
        
        Write-Host "`n✅ Ready for power investigation!" -ForegroundColor Green
        
        # 電源問題の簡易チェック
        Write-Host "`n3. Quick power issue preview..." -ForegroundColor Yellow
        $quickCheck = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            try {
                $shutdowns = Get-EventLog -LogName System | Where-Object {$_.EventID -eq 6008}
                $shutdownCount = ($shutdowns | Measure-Object).Count
                
                $powerErrors = Get-EventLog -LogName System -EntryType Error,Warning -Newest 100 | 
                              Where-Object {$_.Source -like "*Power*" -or $_.Source -like "*Kernel-Power*"}
                $errorCount = ($powerErrors | Measure-Object).Count
                
                @{
                    UnexpectedShutdowns = $shutdownCount
                    PowerErrors = $errorCount
                    LastBoot = (Get-WmiObject Win32_OperatingSystem).LastBootUpTime
                }
            } catch {
                @{
                    UnexpectedShutdowns = "Error retrieving data"
                    PowerErrors = "Error retrieving data"
                    LastBoot = "Error retrieving data"
                }
            }
        }
        
        Write-Host "Quick Check Results:" -ForegroundColor Cyan
        Write-Host "  - Unexpected shutdowns: $($quickCheck.UnexpectedShutdowns)" -ForegroundColor White
        Write-Host "  - Power-related errors: $($quickCheck.PowerErrors)" -ForegroundColor White
        Write-Host "  - Last boot: $($quickCheck.LastBoot)" -ForegroundColor White
        
        if ($quickCheck.UnexpectedShutdowns -gt 0 -or $quickCheck.PowerErrors -gt 0) {
            Write-Host "`n⚠️ Power issues detected! Full investigation recommended." -ForegroundColor Yellow
        } else {
            Write-Host "`n✅ No immediate power issues detected." -ForegroundColor Green
        }
        
    } else {
        Write-Host "`n⚠️ User 'pc' does not have administrative privileges" -ForegroundColor Yellow
        Write-Host "To add admin privileges, run on target PC (as Administrator):" -ForegroundColor Gray
        Write-Host 'Add-LocalGroupMember -Group "Administrators" -Member "pc"' -ForegroundColor White
    }
    
} catch {
    Write-Host "`n❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host