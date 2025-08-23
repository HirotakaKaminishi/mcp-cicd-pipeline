# リモート電源問題調査スクリプト
# 調査側PCから対象PC（192.168.111.163）を調査

$targetPC = "192.168.111.163"
$resultFile = "C:\Users\hirotaka\Documents\work\auth\power_investigation_result_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Write-Host "=== Remote Power Investigation ===" -ForegroundColor Green
Write-Host "Target PC: $targetPC" -ForegroundColor Cyan
Write-Host "Starting investigation..." -ForegroundColor Yellow

# 調査結果を記録
Start-Transcript -Path $resultFile

try {
    # 1. 対象PCの基本情報
    Write-Host "`n[1] System Information" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $sysInfo = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        Get-ComputerInfo | Select-Object `
            WindowsProductName,
            WindowsVersion,
            CsManufacturer,
            CsModel,
            CsSystemType,
            TotalPhysicalMemory
    }
    $sysInfo | Format-List
    
    # 2. 予期しないシャットダウン（Event ID 6008）
    Write-Host "`n[2] Unexpected Shutdowns (Event ID 6008)" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $unexpectedShutdowns = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 6008} | 
            Select-Object -First 10 TimeGenerated, Message
    }
    
    if ($unexpectedShutdowns) {
        Write-Host "Found $($unexpectedShutdowns.Count) unexpected shutdown(s):" -ForegroundColor Red
        $unexpectedShutdowns | Format-Table -AutoSize -Wrap
    } else {
        Write-Host "No unexpected shutdowns found" -ForegroundColor Green
    }
    
    # 3. 電源関連エラー（Kernel-Power）
    Write-Host "`n[3] Power-Related Errors (Kernel-Power)" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $powerErrors = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        Get-EventLog -LogName System -EntryType Error,Warning -Newest 100 | 
            Where-Object {$_.Source -like "*Power*" -or $_.Source -like "*Kernel-Power*"} |
            Select-Object -First 10 TimeGenerated, EntryType, Source, EventID, Message
    }
    
    if ($powerErrors) {
        Write-Host "Found $($powerErrors.Count) power-related error(s):" -ForegroundColor Red
        $powerErrors | Format-Table -AutoSize -Wrap
    } else {
        Write-Host "No power-related errors found" -ForegroundColor Green
    }
    
    # 4. 正常なシャットダウン（Event ID 1074）
    Write-Host "`n[4] Normal Shutdowns (Event ID 1074)" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $normalShutdowns = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 1074} | 
            Select-Object -First 5 TimeGenerated, Message
    }
    
    if ($normalShutdowns) {
        $normalShutdowns | Format-Table -AutoSize -Wrap
    }
    
    # 5. ブルースクリーン情報（BugCheck）
    Write-Host "`n[5] Blue Screen History (BugCheck)" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $bugChecks = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 1001 -and $_.Source -eq "BugCheck"} |
            Select-Object -First 5 TimeGenerated, Message
    }
    
    if ($bugChecks) {
        Write-Host "Found $($bugChecks.Count) blue screen(s):" -ForegroundColor Red
        $bugChecks | Format-Table -AutoSize -Wrap
    } else {
        Write-Host "No blue screens found" -ForegroundColor Green
    }
    
    # 6. 電源設定
    Write-Host "`n[6] Power Configuration" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $powerConfig = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        powercfg /list
    }
    Write-Host $powerConfig
    
    # 7. 最後のウェイクアップ
    Write-Host "`n[7] Last Wake Information" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $lastWake = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        powercfg /lastwake
    }
    Write-Host $lastWake
    
    # 8. バッテリー情報（ノートPCの場合）
    Write-Host "`n[8] Battery Information" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $battery = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    }
    
    if ($battery) {
        $battery | Select-Object Name, EstimatedChargeRemaining, BatteryStatus | Format-List
    } else {
        Write-Host "No battery detected (Desktop PC)" -ForegroundColor Gray
    }
    
    # 9. 温度情報
    Write-Host "`n[9] Temperature Information" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $temps = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        try {
            Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        } catch {
            $null
        }
    }
    
    if ($temps) {
        foreach ($temp in $temps) {
            $celsius = ($temp.CurrentTemperature - 2732) / 10
            Write-Host "Temperature: $celsius °C" -ForegroundColor White
        }
    } else {
        Write-Host "Temperature information not available" -ForegroundColor Gray
    }
    
    # 10. メモリダンプ設定
    Write-Host "`n[10] Memory Dump Settings" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $dumpSettings = Invoke-Command -ComputerName $targetPC -ScriptBlock {
        Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -ErrorAction SilentlyContinue
    }
    
    if ($dumpSettings) {
        Write-Host "Auto Reboot: $($dumpSettings.AutoReboot)"
        Write-Host "Dump File: $($dumpSettings.DumpFile)"
        Write-Host "Crash Dump Enabled: $($dumpSettings.CrashDumpEnabled)"
    }
    
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "Investigation Complete!" -ForegroundColor Green
    Write-Host "Results saved to: $resultFile" -ForegroundColor Cyan
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nTrying with credentials..." -ForegroundColor Yellow
    Write-Host "Please enter credentials for the target PC:" -ForegroundColor Cyan
} finally {
    Stop-Transcript
}

# 結果ファイルを開く
Write-Host "`nOpen result file? (Y/N): " -NoNewline -ForegroundColor Yellow
$choice = Read-Host
if ($choice -eq 'Y' -or $choice -eq 'y') {
    notepad $resultFile
}