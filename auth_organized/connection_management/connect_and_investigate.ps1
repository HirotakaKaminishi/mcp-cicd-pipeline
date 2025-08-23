# 対象PCへの接続と電源問題調査
# 調査側PCで実行

$targetPC = "192.168.111.163"

Write-Host "=== Power Investigation via Remote Connection ===" -ForegroundColor Green
Write-Host "Target PC: $targetPC" -ForegroundColor Cyan
Write-Host "`nConnection established. WinRM is responding." -ForegroundColor Green

Write-Host "`n📝 Authentication Information:" -ForegroundColor Yellow
Write-Host "Please enter the LOCAL account credentials for the target PC" -ForegroundColor White
Write-Host "Username examples:" -ForegroundColor Gray
Write-Host "  - pc" -ForegroundColor Gray
Write-Host "  - Administrator" -ForegroundColor Gray
Write-Host "  - WINDOWS-8R73QDH\pc (if computer name is WINDOWS-8R73QDH)" -ForegroundColor Gray

$username = Read-Host "`nEnter username"
$password = Read-Host "Enter password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

Write-Host "`nConnecting to $targetPC..." -ForegroundColor Yellow

try {
    # 接続テスト
    $testResult = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        @{
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            DateTime = Get-Date
        }
    } -ErrorAction Stop
    
    Write-Host "`n✅ Connection successful!" -ForegroundColor Green
    Write-Host "Connected to: $($testResult.ComputerName)" -ForegroundColor Cyan
    Write-Host "As user: $($testResult.UserName)" -ForegroundColor Cyan
    
    # 電源問題調査開始
    Write-Host "`n🔍 Starting power investigation..." -ForegroundColor Yellow
    
    # 1. 予期しないシャットダウン
    Write-Host "`n[1] Checking for unexpected shutdowns (Event ID 6008)..." -ForegroundColor Yellow
    $shutdowns = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $events = Get-EventLog -LogName System -ErrorAction SilentlyContinue | 
            Where-Object {$_.EventID -eq 6008} | 
            Select-Object -First 10 TimeGenerated, Message
        
        if ($events) {
            @{
                Count = $events.Count
                Events = $events
            }
        } else {
            @{
                Count = 0
                Events = $null
            }
        }
    }
    
    if ($shutdowns.Count -gt 0) {
        Write-Host "❌ Found $($shutdowns.Count) unexpected shutdown(s)!" -ForegroundColor Red
        $shutdowns.Events | Format-Table TimeGenerated -AutoSize
    } else {
        Write-Host "✅ No unexpected shutdowns found" -ForegroundColor Green
    }
    
    # 2. 電源関連エラー
    Write-Host "`n[2] Checking for power-related errors..." -ForegroundColor Yellow
    $powerErrors = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $errors = Get-EventLog -LogName System -EntryType Error,Warning -Newest 100 -ErrorAction SilentlyContinue | 
            Where-Object {$_.Source -like "*Power*" -or $_.Source -like "*Kernel-Power*"} |
            Select-Object -First 10 TimeGenerated, EntryType, Source, EventID
        
        if ($errors) {
            @{
                Count = $errors.Count
                Errors = $errors
            }
        } else {
            @{
                Count = 0
                Errors = $null
            }
        }
    }
    
    if ($powerErrors.Count -gt 0) {
        Write-Host "⚠️ Found $($powerErrors.Count) power-related error(s)" -ForegroundColor Yellow
        $powerErrors.Errors | Format-Table TimeGenerated, EventID, Source -AutoSize
    } else {
        Write-Host "✅ No power-related errors found" -ForegroundColor Green
    }
    
    # 3. システム情報
    Write-Host "`n[3] Getting system information..." -ForegroundColor Yellow
    $sysInfo = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $cs = Get-WmiObject Win32_ComputerSystem
        $os = Get-WmiObject Win32_OperatingSystem
        @{
            Manufacturer = $cs.Manufacturer
            Model = $cs.Model
            TotalRAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
            OS = $os.Caption
            LastBoot = $os.LastBootUpTime
        }
    }
    
    Write-Host "System Information:" -ForegroundColor Cyan
    $sysInfo | Format-List
    
    # 4. 最後のウェイクアップ
    Write-Host "`n[4] Last wake information..." -ForegroundColor Yellow
    $lastWake = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        powercfg /lastwake
    }
    Write-Host $lastWake
    
    # 5. 電源プラン
    Write-Host "`n[5] Power plans..." -ForegroundColor Yellow
    $powerPlans = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        powercfg /list
    }
    Write-Host $powerPlans
    
    # 結果サマリー
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "📊 Investigation Summary:" -ForegroundColor Green
    Write-Host "- Unexpected shutdowns: $($shutdowns.Count)" -ForegroundColor White
    Write-Host "- Power-related errors: $($powerErrors.Count)" -ForegroundColor White
    Write-Host "- System: $($sysInfo.Manufacturer) $($sysInfo.Model)" -ForegroundColor White
    Write-Host "- RAM: $($sysInfo.TotalRAM_GB) GB" -ForegroundColor White
    Write-Host "- Last boot: $($sysInfo.LastBoot)" -ForegroundColor White
    
    if ($shutdowns.Count -gt 0 -or $powerErrors.Count -gt 0) {
        Write-Host "`n⚠️ Power issues detected!" -ForegroundColor Yellow
        Write-Host "Recommended actions:" -ForegroundColor Cyan
        Write-Host "1. Check power supply unit (PSU)" -ForegroundColor White
        Write-Host "2. Monitor CPU/GPU temperatures" -ForegroundColor White
        Write-Host "3. Test RAM with Windows Memory Diagnostic" -ForegroundColor White
        Write-Host "4. Update BIOS and drivers" -ForegroundColor White
        Write-Host "5. Check for loose connections" -ForegroundColor White
    } else {
        Write-Host "`n✅ No obvious power issues detected" -ForegroundColor Green
    }
    
} catch {
    Write-Host "`n❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*Access is denied*") {
        Write-Host "`nAuthentication failed. Please check:" -ForegroundColor Yellow
        Write-Host "1. Username and password are correct" -ForegroundColor White
        Write-Host "2. Account has administrative privileges on target PC" -ForegroundColor White
        Write-Host "3. Try format: COMPUTERNAME\username" -ForegroundColor White
    }
}

Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
Read-Host