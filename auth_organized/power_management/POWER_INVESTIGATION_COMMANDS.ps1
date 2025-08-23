# 電源問題調査コマンド集
# 対象PC（192.168.111.163）で直接実行してください

Write-Host "=== 電源問題調査開始 ===" -ForegroundColor Green
Write-Host "実行時刻: $(Get-Date)" -ForegroundColor Cyan
Write-Host "=" * 60

# 調査結果保存先
$resultFile = "$env:USERPROFILE\Desktop\power_investigation_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# 調査内容を記録開始
Start-Transcript -Path $resultFile

try {
    # 1. システム基本情報
    Write-Host "`n[1] システム情報" -ForegroundColor Yellow
    Write-Host "-" * 40
    $computerInfo = Get-ComputerInfo | Select-Object `
        WindowsProductName, `
        WindowsVersion, `
        OsHardwareAbstractionLayer, `
        CsManufacturer, `
        CsModel, `
        CsSystemType, `
        BiosSMBIOSBIOSVersion, `
        BiosManufacturer, `
        TotalPhysicalMemory
    $computerInfo | Format-List
    
    # 2. 予期しないシャットダウン（Event ID 6008）
    Write-Host "`n[2] 予期しないシャットダウン履歴 (Event ID 6008)" -ForegroundColor Yellow
    Write-Host "-" * 40
    try {
        $unexpectedShutdowns = Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 6008} | 
            Select-Object -First 10 TimeGenerated, Message
        
        if ($unexpectedShutdowns) {
            $unexpectedShutdowns | Format-Table -AutoSize -Wrap
            Write-Host "合計発生回数: $($unexpectedShutdowns.Count)" -ForegroundColor Red
        } else {
            Write-Host "予期しないシャットダウンは検出されませんでした" -ForegroundColor Green
        }
    } catch {
        Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 3. 正常なシャットダウン/再起動（Event ID 1074）
    Write-Host "`n[3] 正常なシャットダウン/再起動履歴 (Event ID 1074)" -ForegroundColor Yellow
    Write-Host "-" * 40
    try {
        $normalShutdowns = Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 1074} | 
            Select-Object -First 5 TimeGenerated, Message
        
        if ($normalShutdowns) {
            $normalShutdowns | Format-Table -AutoSize -Wrap
        }
    } catch {
        Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 4. 電源関連のエラー
    Write-Host "`n[4] 電源関連エラー (Kernel-Power)" -ForegroundColor Yellow
    Write-Host "-" * 40
    try {
        $powerErrors = Get-EventLog -LogName System -EntryType Error,Warning -Newest 100 | 
            Where-Object {$_.Source -like "*Power*" -or $_.Source -like "*Kernel-Power*"} |
            Select-Object -First 10 TimeGenerated, EntryType, Source, EventID, Message
        
        if ($powerErrors) {
            $powerErrors | Format-Table -AutoSize -Wrap
            Write-Host "電源関連エラー数: $($powerErrors.Count)" -ForegroundColor Red
        } else {
            Write-Host "電源関連エラーは検出されませんでした" -ForegroundColor Green
        }
    } catch {
        Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 5. ブルースクリーン情報（BugCheck）
    Write-Host "`n[5] ブルースクリーン履歴 (BugCheck)" -ForegroundColor Yellow
    Write-Host "-" * 40
    try {
        $bugChecks = Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 1001 -and $_.Source -eq "BugCheck"} |
            Select-Object -First 5 TimeGenerated, Message
        
        if ($bugChecks) {
            $bugChecks | Format-Table -AutoSize -Wrap
            Write-Host "BSOD発生回数: $($bugChecks.Count)" -ForegroundColor Red
        } else {
            Write-Host "ブルースクリーンは検出されませんでした" -ForegroundColor Green
        }
    } catch {
        Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 6. 電源設定
    Write-Host "`n[6] 現在の電源設定" -ForegroundColor Yellow
    Write-Host "-" * 40
    & powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTMAX | Select-String -Pattern "電源設定|Power Setting|現在|Current|値|Value"
    
    # 7. 最後のウェイクアップ原因
    Write-Host "`n[7] 最後のウェイクアップ原因" -ForegroundColor Yellow
    Write-Host "-" * 40
    & powercfg /lastwake
    
    # 8. スリープ可能デバイス
    Write-Host "`n[8] ウェイクアップ可能デバイス" -ForegroundColor Yellow
    Write-Host "-" * 40
    & powercfg /devicequery wake_armed
    
    # 9. バッテリー情報（ノートPCの場合）
    Write-Host "`n[9] バッテリー情報" -ForegroundColor Yellow
    Write-Host "-" * 40
    try {
        $battery = Get-WmiObject -Class Win32_Battery
        if ($battery) {
            $battery | Select-Object Name, EstimatedChargeRemaining, BatteryStatus, EstimatedRunTime | Format-List
        } else {
            Write-Host "バッテリーは検出されませんでした（デスクトップPC）" -ForegroundColor Gray
        }
    } catch {
        Write-Host "バッテリー情報取得エラー: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 10. 温度情報（可能な場合）
    Write-Host "`n[10] ハードウェア温度情報" -ForegroundColor Yellow
    Write-Host "-" * 40
    try {
        $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($temps) {
            foreach ($temp in $temps) {
                $celsius = ($temp.CurrentTemperature - 2732) / 10
                Write-Host "温度: $celsius °C" -ForegroundColor White
            }
        } else {
            Write-Host "温度センサー情報を取得できませんでした" -ForegroundColor Gray
        }
    } catch {
        Write-Host "温度情報は利用できません" -ForegroundColor Gray
    }
    
    # 11. メモリダンプ設定
    Write-Host "`n[11] メモリダンプ設定" -ForegroundColor Yellow
    Write-Host "-" * 40
    $crashControl = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
    Write-Host "自動再起動: $($crashControl.AutoReboot)"
    Write-Host "ダンプファイル: $($crashControl.DumpFile)"
    Write-Host "ダンプタイプ: $($crashControl.CrashDumpEnabled)"
    
    # 結果サマリー
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "調査完了！" -ForegroundColor Green
    Write-Host "結果は以下に保存されました:" -ForegroundColor Yellow
    Write-Host $resultFile -ForegroundColor Cyan
    
} catch {
    Write-Host "調査中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Stop-Transcript
}

# 結果ファイルを開く
Write-Host "`n結果ファイルを開きますか？ (Y/N): " -NoNewline -ForegroundColor Yellow
$choice = Read-Host
if ($choice -eq 'Y' -or $choice -eq 'y') {
    notepad $resultFile
}

Write-Host "`n調査結果を調査側PCに送信する場合は、以下のファイルを転送してください:" -ForegroundColor Cyan
Write-Host $resultFile -ForegroundColor White
Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
Read-Host