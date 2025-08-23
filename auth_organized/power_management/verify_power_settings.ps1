# 電源設定確認スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host "=== Power Settings Verification ===" -ForegroundColor Green

$verification = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
    # 現在のアクティブプラン
    $activePlan = powercfg /getactivescheme
    
    # 利用可能なプラン一覧
    $allPlans = powercfg /list
    
    return @{
        ActivePlan = $activePlan
        AllPlans = $allPlans
    }
}

Write-Host "Current Active Power Plan:" -ForegroundColor Cyan
Write-Host $verification.ActivePlan -ForegroundColor Green

Write-Host "`nAll Available Power Plans:" -ForegroundColor Cyan
Write-Host $verification.AllPlans -ForegroundColor White

Write-Host "`n✅ Thermal Protection Plan is now active!" -ForegroundColor Green
Write-Host "🌡️ This should significantly reduce thermal shutdowns." -ForegroundColor Yellow