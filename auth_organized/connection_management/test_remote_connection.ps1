# リモート接続テストスクリプト
Write-Host "=== Testing Remote Connection to 192.168.111.163 ===" -ForegroundColor Green

# 基本的な接続テスト
Write-Host "`n1. Testing WinRM connection..." -ForegroundColor Yellow
Test-WSMan -ComputerName 192.168.111.163

# 認証情報を使った簡単なコマンド実行
Write-Host "`n2. Testing with credentials..." -ForegroundColor Yellow
Write-Host "Enter credentials for target PC (username: pc):" -ForegroundColor Cyan
$cred = Get-Credential -Message "Target PC credentials"

if ($cred) {
    try {
        $result = Invoke-Command -ComputerName 192.168.111.163 -Credential $cred -ScriptBlock {
            @{
                ComputerName = $env:COMPUTERNAME
                UserName = $env:USERNAME
                Time = Get-Date
                Message = "Connection successful!"
            }
        } -ErrorAction Stop
        
        Write-Host "`n✅ Connection successful!" -ForegroundColor Green
        $result | Format-List
        
        Write-Host "`nYou can now run power investigation commands!" -ForegroundColor Cyan
        
    } catch {
        Write-Host "`n❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nPossible issues:" -ForegroundColor Yellow
        Write-Host "- TrustedHosts not configured (run setup_trustedhosts.bat as admin)" -ForegroundColor White
        Write-Host "- Wrong credentials" -ForegroundColor White
        Write-Host "- PSRemoting not enabled on target PC" -ForegroundColor White
    }
}

Read-Host "`nPress Enter to exit"