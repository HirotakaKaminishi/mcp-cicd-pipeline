# SSH サーバ状態確認スクリプト
Write-Host "=== SSH Server Status Check ===" -ForegroundColor Green

try {
    # サービス状態確認
    Write-Host "`n1. SSH Service Status:" -ForegroundColor Yellow
    $sshdService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
    if ($sshdService) {
        Write-Host "   Service: $($sshdService.Name)" -ForegroundColor White
        Write-Host "   Status: $($sshdService.Status)" -ForegroundColor White
        Write-Host "   StartType: $($sshdService.StartType)" -ForegroundColor White
    } else {
        Write-Host "   SSH service not found" -ForegroundColor Red
    }
    
    # OpenSSH Server機能確認
    Write-Host "`n2. OpenSSH Server Feature:" -ForegroundColor Yellow
    $sshFeature = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($sshFeature) {
        Write-Host "   Feature: $($sshFeature.Name)" -ForegroundColor White
        Write-Host "   State: $($sshFeature.State)" -ForegroundColor White
    } else {
        Write-Host "   OpenSSH.Server feature not found" -ForegroundColor Red
    }
    
    # ポート確認
    Write-Host "`n3. Port Status:" -ForegroundColor Yellow
    $ports = @(22, 2222)
    foreach ($port in $ports) {
        $connection = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
        $status = if ($connection.TcpTestSucceeded) { "Open" } else { "Closed" }
        Write-Host "   Port $port`: $status" -ForegroundColor White
    }
    
    # プロセス確認
    Write-Host "`n4. SSH Processes:" -ForegroundColor Yellow
    $sshProcesses = Get-Process | Where-Object {$_.Name -like "*ssh*"}
    if ($sshProcesses) {
        foreach ($proc in $sshProcesses) {
            Write-Host "   $($proc.Name) (PID: $($proc.Id))" -ForegroundColor White
        }
    } else {
        Write-Host "   No SSH processes found" -ForegroundColor Red
    }
    
    # ファイアウォール規則確認
    Write-Host "`n5. Firewall Rules:" -ForegroundColor Yellow
    $firewallRules = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*SSH*" -or $_.DisplayName -like "*OpenSSH*"}
    if ($firewallRules) {
        foreach ($rule in $firewallRules) {
            Write-Host "   $($rule.DisplayName): $($rule.Enabled)" -ForegroundColor White
        }
    } else {
        Write-Host "   No SSH firewall rules found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Status Check Complete ===" -ForegroundColor Green