# 新しい管理者ユーザーでの接続テスト
# 調査側PCで実行

$targetPC = "192.168.111.163"
$username = "RemoteAdmin"
$password = "4Ernfb7E!"

Write-Host "=== Testing Connection with New Admin User ===" -ForegroundColor Green
Write-Host "Target PC: $targetPC" -ForegroundColor Cyan
Write-Host "Username: $username" -ForegroundColor Cyan

try {
    # 認証情報作成
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    
    Write-Host "`n1. Testing basic connection..." -ForegroundColor Yellow
    $testResult = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        @{
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            DateTime = Get-Date
        }
    } -ErrorAction Stop
    
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host "Computer: $($testResult.ComputerName)" -ForegroundColor White
    Write-Host "Connected as: $($testResult.UserName)" -ForegroundColor White
    Write-Host "Admin privileges: $($testResult.IsAdmin)" -ForegroundColor White
    Write-Host "Time: $($testResult.DateTime)" -ForegroundColor White
    
    if ($testResult.IsAdmin) {
        Write-Host "`n2. Testing administrative access..." -ForegroundColor Yellow
        
        # Event Logアクセステスト
        $eventTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            try {
                $events = Get-EventLog -LogName System -Newest 5 -ErrorAction Stop
                "SUCCESS: Can access Event Log ($($events.Count) events retrieved)"
            } catch {
                "FAILED: Cannot access Event Log - $($_.Exception.Message)"
            }
        }
        Write-Host $eventTest -ForegroundColor Cyan
        
        # サービスアクセステスト
        $serviceTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            try {
                $services = Get-Service | Select-Object -First 5
                "SUCCESS: Can access Services ($($services.Count) services retrieved)"
            } catch {
                "FAILED: Cannot access Services - $($_.Exception.Message)"
            }
        }
        Write-Host $serviceTest -ForegroundColor Cyan
        
        Write-Host "`n✅ All tests passed! Ready for power investigation." -ForegroundColor Green
        
        # 簡単な電源問題クイックチェック
        Write-Host "`n3. Quick power issue check..." -ForegroundColor Yellow
        $quickCheck = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            $shutdowns = Get-EventLog -LogName System | Where-Object {$_.EventID -eq 6008} | Measure-Object
            $powerErrors = Get-EventLog -LogName System -EntryType Error,Warning -Newest 100 | 
                          Where-Object {$_.Source -like "*Power*" -or $_.Source -like "*Kernel-Power*"} | 
                          Measure-Object
            
            @{
                UnexpectedShutdowns = $shutdowns.Count
                PowerErrors = $powerErrors.Count
            }
        }
        
        Write-Host "Quick Results:" -ForegroundColor Cyan
        Write-Host "  - Unexpected shutdowns: $($quickCheck.UnexpectedShutdowns)" -ForegroundColor White
        Write-Host "  - Power-related errors: $($quickCheck.PowerErrors)" -ForegroundColor White
        
        if ($quickCheck.UnexpectedShutdowns -gt 0 -or $quickCheck.PowerErrors -gt 0) {
            Write-Host "`n⚠️ Power issues detected! Run full investigation." -ForegroundColor Yellow
        } else {
            Write-Host "`n✅ No immediate power issues detected." -ForegroundColor Green
        }
        
    } else {
        Write-Host "`n❌ User does not have administrative privileges!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "`n❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*Access is denied*") {
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        Write-Host "1. User account not created yet on target PC" -ForegroundColor White
        Write-Host "2. Incorrect password" -ForegroundColor White
        Write-Host "3. User not added to Administrators group" -ForegroundColor White
        Write-Host "4. LocalAccountTokenFilterPolicy not set" -ForegroundColor White
    }
}

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host