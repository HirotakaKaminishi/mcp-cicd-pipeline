# 認証情報付きリモート電源問題調査
# 調査側PCから実行

$targetPC = "192.168.111.163"
$resultFile = "C:\Users\hirotaka\Documents\work\auth\power_result_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Write-Host "=== Remote Power Investigation with Credentials ===" -ForegroundColor Green
Write-Host "Target PC: $targetPC" -ForegroundColor Cyan

# 認証情報を取得
Write-Host "`nPlease enter credentials for target PC:" -ForegroundColor Yellow
Write-Host "Username format: pc (local user) or COMPUTERNAME\pc" -ForegroundColor Gray
$cred = Get-Credential -Message "Enter credentials for $targetPC"

if (-not $cred) {
    Write-Host "Credentials required. Exiting." -ForegroundColor Red
    exit
}

Write-Host "`nStarting investigation..." -ForegroundColor Yellow

# 簡易調査を実行
try {
    # 1. 接続テスト
    Write-Host "`n[1] Testing connection..." -ForegroundColor Yellow
    $testConnection = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $env:COMPUTERNAME
    } -ErrorAction Stop
    Write-Host "✅ Connected to: $testConnection" -ForegroundColor Green
    
    # 2. 予期しないシャットダウン確認
    Write-Host "`n[2] Checking unexpected shutdowns (Event ID 6008)..." -ForegroundColor Yellow
    $shutdowns = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $events = Get-EventLog -LogName System | Where-Object {$_.EventID -eq 6008} | Select-Object -First 10
        if ($events) {
            $events | Select-Object TimeGenerated, Message
        } else {
            "No unexpected shutdowns found"
        }
    }
    
    Write-Host "Result:" -ForegroundColor Cyan
    $shutdowns | Format-Table -AutoSize
    
    # 3. 電源関連エラー確認
    Write-Host "`n[3] Checking power-related errors..." -ForegroundColor Yellow
    $powerErrors = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $errors = Get-EventLog -LogName System -EntryType Error,Warning -Newest 50 | 
            Where-Object {$_.Source -like "*Power*" -or $_.Source -like "*Kernel-Power*"} |
            Select-Object -First 10
        if ($errors) {
            $errors | Select-Object TimeGenerated, EntryType, Source, EventID
        } else {
            "No power-related errors found"
        }
    }
    
    Write-Host "Result:" -ForegroundColor Cyan
    $powerErrors | Format-Table -AutoSize
    
    # 4. システム情報取得
    Write-Host "`n[4] Getting system information..." -ForegroundColor Yellow
    $sysInfo = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        @{
            ComputerName = $env:COMPUTERNAME
            OS = (Get-WmiObject Win32_OperatingSystem).Caption
            Manufacturer = (Get-WmiObject Win32_ComputerSystem).Manufacturer
            Model = (Get-WmiObject Win32_ComputerSystem).Model
            TotalRAM = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        }
    }
    
    Write-Host "System Information:" -ForegroundColor Cyan
    $sysInfo | Format-List
    
    # 5. 最後のウェイクアップ情報
    Write-Host "`n[5] Getting last wake information..." -ForegroundColor Yellow
    $lastWake = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        powercfg /lastwake
    }
    Write-Host $lastWake
    
    # 結果をファイルに保存
    $allResults = @"
=== Power Investigation Results ===
Date: $(Get-Date)
Target PC: $targetPC

[System Information]
$($sysInfo | Out-String)

[Unexpected Shutdowns]
$($shutdowns | Out-String)

[Power Errors]
$($powerErrors | Out-String)

[Last Wake]
$lastWake
"@
    
    $allResults | Out-File -FilePath $resultFile
    Write-Host "`n✅ Investigation complete!" -ForegroundColor Green
    Write-Host "Results saved to: $resultFile" -ForegroundColor Cyan
    
} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure target PC has PSRemoting enabled" -ForegroundColor White
    Write-Host "2. Check firewall settings on both PCs" -ForegroundColor White
    Write-Host "3. Verify credentials are correct" -ForegroundColor White
    Write-Host "4. Try username format: COMPUTERNAME\username" -ForegroundColor White
}

Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
Read-Host