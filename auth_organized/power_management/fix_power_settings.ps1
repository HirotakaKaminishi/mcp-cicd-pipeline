# 電源設定修正スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "=== FIXING POWER SETTINGS ===" -ForegroundColor Red

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`nRe-applying thermal protection settings..." -ForegroundColor Yellow
    
    $fixResult = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @()
        
        # 現在のアクティブプランのGUIDを取得
        $activeGUID = (powercfg /getactivescheme).Split()[3]
        $results += "Working with plan GUID: $activeGUID"
        
        # CPU最大パフォーマンスを再設定（16進数で）
        powercfg /setacvalueindex $activeGUID SUB_PROCESSOR PROCTHROTMAX 85
        $results += "Set AC CPU Max Performance: 85%"
        
        powercfg /setdcvalueindex $activeGUID SUB_PROCESSOR PROCTHROTMAX 80
        $results += "Set DC CPU Max Performance: 80%"
        
        # CPU最小パフォーマンスを再設定
        powercfg /setacvalueindex $activeGUID SUB_PROCESSOR PROCTHROTMIN 10
        $results += "Set AC CPU Min Performance: 10%"
        
        powercfg /setdcvalueindex $activeGUID SUB_PROCESSOR PROCTHROTMIN 5
        $results += "Set DC CPU Min Performance: 5%"
        
        # ターボブーストを無効化
        powercfg /setacvalueindex $activeGUID SUB_PROCESSOR PERFBOOSTMODE 0
        $results += "Disabled Turbo Boost (AC)"
        
        powercfg /setdcvalueindex $activeGUID SUB_PROCESSOR PERFBOOSTMODE 0
        $results += "Disabled Turbo Boost (DC)"
        
        # システム冷却ポリシーをアクティブに設定
        powercfg /setacvalueindex $activeGUID SUB_PROCESSOR SYSCOOLPOL 1
        $results += "Set Active Cooling Policy (AC)"
        
        powercfg /setdcvalueindex $activeGUID SUB_PROCESSOR SYSCOOLPOL 1
        $results += "Set Active Cooling Policy (DC)"
        
        # 設定を適用
        powercfg /setactive $activeGUID
        $results += "Applied settings to active plan"
        
        return $results
    }
    
    Write-Host "`nFix Results:" -ForegroundColor Cyan
    foreach ($result in $fixResult) {
        Write-Host "  $result" -ForegroundColor Green
    }
    
    Write-Host "`nVerifying fixed settings..." -ForegroundColor Yellow
    
    $verification = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @{}
        
        # 現在のアクティブプラン
        $activePlan = powercfg /getactivescheme
        $results.ActivePlan = $activePlan
        
        # CPU設定の16進数値を直接確認
        $cpuMax = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTMAX
        $turbo = powercfg /query SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE
        $cooling = powercfg /query SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL
        
        $results.CPUMaxRaw = $cpuMax
        $results.TurboRaw = $turbo
        $results.CoolingRaw = $cooling
        
        return $results
    }
    
    Write-Host "`nActive Plan:" -ForegroundColor Cyan
    Write-Host $verification.ActivePlan -ForegroundColor Green
    
    Write-Host "`nCPU Max Performance Settings:" -ForegroundColor Cyan
    $cpuLines = $verification.CPUMaxRaw -split "`n" | Where-Object { $_ -match "電源設定インデックス.*0x" }
    foreach ($line in $cpuLines) {
        Write-Host "  $line" -ForegroundColor White
    }
    
    Write-Host "`nTurbo Boost Settings:" -ForegroundColor Cyan
    $turboLines = $verification.TurboRaw -split "`n" | Where-Object { $_ -match "電源設定インデックス.*0x" }
    foreach ($line in $turboLines) {
        Write-Host "  $line" -ForegroundColor White
    }
    
    Write-Host "`nCooling Policy Settings:" -ForegroundColor Cyan
    $coolingLines = $verification.CoolingRaw -split "`n" | Where-Object { $_ -match "電源設定インデックス.*0x" }
    foreach ($line in $coolingLines) {
        Write-Host "  $line" -ForegroundColor White
    }
    
    Write-Host "`n" + "=" * 50 -ForegroundColor Green
    Write-Host "POWER SETTINGS FIX COMPLETE" -ForegroundColor Green
    Write-Host "=" * 50 -ForegroundColor Green
    
} catch {
    Write-Host "Fix failed: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"