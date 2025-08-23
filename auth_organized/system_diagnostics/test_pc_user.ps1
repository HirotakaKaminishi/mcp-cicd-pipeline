# 既存ユーザー「pc」での接続テスト
# パスワード：4Ernfb7E

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "=== Testing Connection with User 'pc' ===" -ForegroundColor Green
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
            Groups = (whoami /groups /fo csv | ConvertFrom-Csv | Select-Object -ExpandProperty "Group Name")
        }
    } -ErrorAction Stop
    
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host "Computer: $($testResult.ComputerName)" -ForegroundColor White
    Write-Host "Connected as: $($testResult.UserName)" -ForegroundColor White
    Write-Host "Admin privileges: $($testResult.IsAdmin)" -ForegroundColor White
    Write-Host "Time: $($testResult.DateTime)" -ForegroundColor White
    
    # グループメンバーシップ表示
    Write-Host "`nUser groups:" -ForegroundColor Cyan
    $testResult.Groups | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    
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
        
        # WMIアクセステスト
        $wmiTest = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
            try {
                $system = Get-WmiObject Win32_ComputerSystem -ErrorAction Stop
                "SUCCESS: Can access WMI ($($system.Manufacturer) $($system.Model))"
            } catch {
                "FAILED: Cannot access WMI - $($_.Exception.Message)"
            }
        }
        Write-Host $wmiTest -ForegroundColor Cyan
        
        Write-Host "`n✅ Administrative access confirmed!" -ForegroundColor Green
        
    } else {
        Write-Host "`n⚠️ User does not have administrative privileges" -ForegroundColor Yellow
        Write-Host "To add admin privileges, run on target PC:" -ForegroundColor Gray
        Write-Host 'Add-LocalGroupMember -Group "Administrators" -Member "pc"' -ForegroundColor Gray
    }
    
} catch {
    Write-Host "`n❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*Access is denied*") {
        Write-Host "`nPossible causes:" -ForegroundColor Yellow
        Write-Host "1. Incorrect password" -ForegroundColor White
        Write-Host "2. User account is disabled" -ForegroundColor White
        Write-Host "3. Account lockout policy" -ForegroundColor White
    }
    
    Write-Host "`nTry different username formats:" -ForegroundColor Cyan
    Write-Host "1. pc" -ForegroundColor Gray
    Write-Host "2. .\pc" -ForegroundColor Gray
    Write-Host "3. $($testResult.ComputerName)\pc" -ForegroundColor Gray
}

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host