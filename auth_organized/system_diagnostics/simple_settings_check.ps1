# シンプルな電源設定確認

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

Write-Host "=== Power Plan Status Check ===" -ForegroundColor Green

$result = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
    # アクティブプラン確認
    $active = powercfg /getactivescheme
    
    # 利用可能プラン一覧
    $list = powercfg /list
    
    return @{
        Active = $active
        List = $list
    }
}

Write-Host "`nCurrent Active Plan:" -ForegroundColor Cyan
Write-Host $result.Active -ForegroundColor Green

Write-Host "`nAll Available Plans:" -ForegroundColor Cyan
Write-Host $result.List -ForegroundColor White

# Thermal Protection Planがアクティブかチェック
if ($result.Active -match "Thermal Protection Plan") {
    Write-Host "`n✅ SUCCESS: Thermal Protection Plan is ACTIVE" -ForegroundColor Green
    Write-Host "🌡️ Thermal shutdown protection is now enabled" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ WARNING: Thermal Protection Plan is NOT active" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"