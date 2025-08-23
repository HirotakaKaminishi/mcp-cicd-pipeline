# 再起動後の接続テストスクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "🎉 Target PC is back online! Testing connection..." -ForegroundColor Green

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`nTesting PowerShell Remoting..." -ForegroundColor Yellow
    
    $systemInfo = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $info = @{}
        
        # 基本システム情報
        $info.ComputerName = $env:COMPUTERNAME
        $info.CurrentTime = Get-Date
        
        # 起動時間
        $os = Get-WmiObject Win32_OperatingSystem
        $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $uptime = (Get-Date) - $lastBoot
        $info.LastBoot = $lastBoot
        $info.Uptime = "$($uptime.Hours)h $($uptime.Minutes)m"
        
        # 電源プラン
        $activePlan = powercfg /getactivescheme
        $info.PowerPlan = $activePlan
        
        # システムスペック
        $cpu = Get-WmiObject Win32_Processor
        $info.CPUName = $cpu.Name
        $info.TotalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        
        return $info
    }
    
    Write-Host "✅ PowerShell Remoting: WORKING" -ForegroundColor Green
    Write-Host "`n📋 System Information:" -ForegroundColor Cyan
    Write-Host "  Computer: $($systemInfo.ComputerName)" -ForegroundColor White
    Write-Host "  Current Time: $($systemInfo.CurrentTime)" -ForegroundColor White
    Write-Host "  Last Boot: $($systemInfo.LastBoot)" -ForegroundColor White
    Write-Host "  Uptime: $($systemInfo.Uptime)" -ForegroundColor White
    
    Write-Host "`n💻 Hardware Specs:" -ForegroundColor Cyan
    Write-Host "  CPU: $($systemInfo.CPUName)" -ForegroundColor White
    Write-Host "  Memory: $($systemInfo.TotalMemoryGB) GB" -ForegroundColor White
    
    Write-Host "`n⚡ Power Management:" -ForegroundColor Cyan
    Write-Host "  $($systemInfo.PowerPlan)" -ForegroundColor Green
    
    if ($systemInfo.PowerPlan -match "Thermal Protection Plan") {
        Write-Host "`n🛡️ SUCCESS: Thermal Protection Plan is ACTIVE after restart!" -ForegroundColor Green
        Write-Host "✅ Thermal protection settings survived the reboot" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ WARNING: Thermal Protection Plan is NOT active" -ForegroundColor Red
        Write-Host "📋 The plan may need to be reactivated" -ForegroundColor Yellow
    }
    
    # WinRM設定確認
    Write-Host "`n🔧 Testing WinRM configuration..." -ForegroundColor Yellow
    
    $winrmStatus = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $config = @{}
        
        # WinRM サービス状態
        $winrmService = Get-Service -Name WinRM
        $config.ServiceStatus = $winrmService.Status
        $config.ServiceStartType = $winrmService.StartType
        
        # TrustedHosts設定
        try {
            $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue
            $config.TrustedHosts = $trustedHosts.Value
        } catch {
            $config.TrustedHosts = "Not configured"
        }
        
        return $config
    }
    
    Write-Host "WinRM Configuration:" -ForegroundColor Cyan
    Write-Host "  Service Status: $($winrmStatus.ServiceStatus)" -ForegroundColor White
    Write-Host "  Start Type: $($winrmStatus.ServiceStartType)" -ForegroundColor White
    Write-Host "  TrustedHosts: $($winrmStatus.TrustedHosts)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 60 -ForegroundColor Green
Write-Host "        CONNECTION TEST COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Read-Host "`nPress Enter to continue"