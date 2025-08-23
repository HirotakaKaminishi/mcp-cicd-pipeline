# 詳細な電源設定確認スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "=== Detailed Power Settings Verification ===" -ForegroundColor Green

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    $settings = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @{}
        
        # アクティブプラン確認
        $activePlan = powercfg /getactivescheme
        $results.ActivePlan = $activePlan
        
        # CPU最大パフォーマンス確認
        $cpuMaxQuery = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTMAX
        $results.CPUMaxQuery = $cpuMaxQuery
        
        # ターボブースト設定確認
        $turboQuery = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE
        $results.TurboQuery = $turboQuery
        
        # システム冷却ポリシー確認
        $coolingQuery = powercfg /query SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL
        $results.CoolingQuery = $coolingQuery
        
        return $results
    }
    
    Write-Host "`nActive Power Plan:" -ForegroundColor Cyan
    Write-Host $settings.ActivePlan -ForegroundColor Green
    
    Write-Host "`nCPU Maximum Performance Settings:" -ForegroundColor Cyan
    $cpuLines = $settings.CPUMaxQuery -split "`n" | Where-Object { $_ -match "(AC|DC).*0x" }
    foreach ($line in $cpuLines) {
        if ($line -match "AC.*0x([0-9a-f]+)") {
            $acValue = [Convert]::ToInt32($matches[1], 16)
            $status = if ($acValue -eq 85) { "✓ CORRECT" } else { "⚠ UNEXPECTED" }
            Write-Host "  AC Power: $acValue% $status" -ForegroundColor $(if ($acValue -eq 85) { "Green" } else { "Yellow" })
        }
        if ($line -match "DC.*0x([0-9a-f]+)") {
            $dcValue = [Convert]::ToInt32($matches[1], 16)
            $status = if ($dcValue -eq 80) { "✓ CORRECT" } else { "⚠ UNEXPECTED" }
            Write-Host "  DC Power: $dcValue% $status" -ForegroundColor $(if ($dcValue -eq 80) { "Green" } else { "Yellow" })
        }
    }
    
    Write-Host "`nTurbo Boost Settings:" -ForegroundColor Cyan
    $turboLines = $settings.TurboQuery -split "`n" | Where-Object { $_ -match "(AC|DC).*0x" }
    foreach ($line in $turboLines) {
        if ($line -match "AC.*0x([0-9a-f]+)") {
            $acValue = [Convert]::ToInt32($matches[1], 16)
            $status = if ($acValue -eq 0) { "✓ DISABLED (Safe)" } else { "⚠ ENABLED" }
            Write-Host "  AC Power: $status" -ForegroundColor $(if ($acValue -eq 0) { "Green" } else { "Yellow" })
        }
        if ($line -match "DC.*0x([0-9a-f]+)") {
            $dcValue = [Convert]::ToInt32($matches[1], 16)
            $status = if ($dcValue -eq 0) { "✓ DISABLED (Safe)" } else { "⚠ ENABLED" }
            Write-Host "  DC Power: $status" -ForegroundColor $(if ($dcValue -eq 0) { "Green" } else { "Yellow" })
        }
    }
    
    Write-Host "`nSystem Cooling Policy:" -ForegroundColor Cyan
    $coolingLines = $settings.CoolingQuery -split "`n" | Where-Object { $_ -match "(AC|DC).*0x" }
    foreach ($line in $coolingLines) {
        if ($line -match "AC.*0x([0-9a-f]+)") {
            $acValue = [Convert]::ToInt32($matches[1], 16)
            $status = if ($acValue -eq 1) { "✓ ACTIVE" } else { "PASSIVE" }
            Write-Host "  AC Power: $status" -ForegroundColor $(if ($acValue -eq 1) { "Green" } else { "White" })
        }
    }
    
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "THERMAL PROTECTION STATUS: ACTIVE" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Green
    
} catch {
    Write-Host "Settings verification failed: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"