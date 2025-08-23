# 電源問題調査スクリプト
# SSH接続後に対象PCで実行

Write-Host "=== Power Issue Investigation ===" -ForegroundColor Green
Write-Host "Analyzing power-related problems..." -ForegroundColor Cyan

# 1. 予期しないシャットダウンの確認
Write-Host "`n1. Unexpected Shutdowns (Event ID 6008):" -ForegroundColor Yellow
try {
    $shutdowns = Get-EventLog -LogName System | Where-Object {$_.EventID -eq 6008} | Select-Object TimeGenerated,Message -First 10
    if ($shutdowns) {
        $shutdowns | Format-Table -AutoSize
    } else {
        Write-Host "No unexpected shutdowns found" -ForegroundColor Green
    }
} catch {
    Write-Host "Error accessing shutdown logs: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. 電源関連エラー
Write-Host "`n2. Power-related Errors:" -ForegroundColor Yellow
try {
    $powerErrors = Get-EventLog -LogName System -EntryType Error,Warning -Newest 50 | Where-Object {
        $_.Source -like "*Power*" -or 
        $_.Source -like "*Kernel-Power*" -or
        $_.Message -like "*power*" -or
        $_.Message -like "*shutdown*"
    }
    
    if ($powerErrors) {
        $powerErrors | Select-Object TimeGenerated,Source,EventID,Message | Format-Table -Wrap
    } else {
        Write-Host "No power-related errors found" -ForegroundColor Green
    }
} catch {
    Write-Host "Error accessing power logs: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. 最後のウェイクアップ原因
Write-Host "`n3. Last Wake Source:" -ForegroundColor Yellow
try {
    $wakeInfo = powercfg /lastwake
    $wakeInfo
} catch {
    Write-Host "Error getting wake information: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. システム情報
Write-Host "`n4. System Information:" -ForegroundColor Yellow
try {
    $sysInfo = Get-WmiObject -Class Win32_ComputerSystem | Select-Object Manufacturer,Model,TotalPhysicalMemory
    $sysInfo | Format-List
    
    $powerSupply = Get-WmiObject -Class Win32_SystemEnclosure | Select-Object ChassisTypes,SMBIOSAssetTag
    $powerSupply | Format-List
} catch {
    Write-Host "Error getting system information: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. CPU・メモリ使用率
Write-Host "`n5. Current Resource Usage:" -ForegroundColor Yellow
try {
    $cpuUsage = Get-Counter '\Processor(_Total)\% Processor Time' | Select-Object -ExpandProperty CounterSamples
    Write-Host "CPU Usage: $([math]::Round($cpuUsage.CookedValue, 2))%" -ForegroundColor White
    
    $memInfo = Get-WmiObject -Class Win32_OperatingSystem
    $memUsed = [math]::Round((($memInfo.TotalVisibleMemorySize - $memInfo.FreePhysicalMemory) / $memInfo.TotalVisibleMemorySize) * 100, 2)
    Write-Host "Memory Usage: $memUsed%" -ForegroundColor White
} catch {
    Write-Host "Error getting resource usage: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. 温度情報（可能であれば）
Write-Host "`n6. Temperature Information:" -ForegroundColor Yellow
try {
    $tempInfo = Get-WmiObject -Namespace "root/OpenHardwareMonitor" -Class Sensor -ErrorAction SilentlyContinue
    if ($tempInfo) {
        $tempInfo | Where-Object {$_.SensorType -eq "Temperature"} | Select-Object Name,Value | Format-Table
    } else {
        Write-Host "Temperature monitoring not available (install HWiNFO64 or similar)" -ForegroundColor Gray
    }
} catch {
    Write-Host "Temperature information not accessible" -ForegroundColor Gray
}

# 7. 電源設定
Write-Host "`n7. Power Configuration:" -ForegroundColor Yellow
try {
    powercfg /query SCHEME_CURRENT SUB_SLEEP
} catch {
    Write-Host "Error getting power configuration: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Investigation Complete ===" -ForegroundColor Green
Write-Host "Review the above information for patterns related to power issues." -ForegroundColor Cyan