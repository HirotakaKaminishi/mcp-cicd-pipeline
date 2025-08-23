# 簡単な温度確認スクリプト

$targetPC = "192.168.111.163"
$username = "pc"  
$password = "4Ernfb7E"

Write-Host "=== Current Temperature Check ===" -ForegroundColor Green
Write-Host "Target: WINDOWS-8R73QDH" -ForegroundColor Cyan

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`nChecking temperatures..." -ForegroundColor Yellow
    
    $results = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $output = @{}
        
        # WMI温度センサー確認
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $tempList = @()
                foreach ($temp in $temps) {
                    $celsius = ($temp.CurrentTemperature - 2732) / 10
                    $tempList += "Thermal Zone: $celsius C"
                }
                $output.WMI_Temps = $tempList
            } else {
                $output.WMI_Temps = "No WMI temperature sensors available"
            }
        } catch {
            $output.WMI_Temps = "WMI temperature check failed"
        }
        
        # CPU使用率
        try {
            $cpu = Get-WmiObject Win32_Processor
            $output.CPU_Load = $cpu.LoadPercentage
        } catch {
            $output.CPU_Load = "Unknown"
        }
        
        # システム稼働時間
        try {
            $os = Get-WmiObject Win32_OperatingSystem
            $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
            $uptime = (Get-Date) - $lastBoot
            $output.Uptime = "$($uptime.Hours)h $($uptime.Minutes)m"
            $output.LastBoot = $lastBoot
        } catch {
            $output.Uptime = "Unknown"
        }
        
        # AMD CPU温度（レジストリ経由）
        try {
            $amdTemp = Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -ErrorAction SilentlyContinue
            $output.AMD_Info = $amdTemp.ProcessorNameString
        } catch {
            $output.AMD_Info = "AMD info not available"
        }
        
        return $output
    }
    
    # 結果表示
    Write-Host "`nTemperature Results:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor White
    
    if ($results.WMI_Temps -is [array]) {
        foreach ($temp in $results.WMI_Temps) {
            Write-Host $temp -ForegroundColor Yellow
        }
    } else {
        Write-Host $results.WMI_Temps -ForegroundColor Gray
    }
    
    Write-Host "`nSystem Status:" -ForegroundColor Cyan
    Write-Host "CPU Load: $($results.CPU_Load)%" -ForegroundColor White
    Write-Host "Uptime: $($results.Uptime)" -ForegroundColor White
    Write-Host "Last Boot: $($results.LastBoot)" -ForegroundColor White
    Write-Host "Processor: $($results.AMD_Info)" -ForegroundColor White
    
    # 温度測定の制限について
    Write-Host "`nNote about temperature monitoring:" -ForegroundColor Yellow
    Write-Host "Windows WMI often does not expose detailed CPU/GPU temperatures" -ForegroundColor Gray
    Write-Host "for security reasons, especially on laptops." -ForegroundColor Gray
    
    Write-Host "`nRecommended temperature monitoring tools:" -ForegroundColor Cyan
    Write-Host "1. HWiNFO64 (most comprehensive)" -ForegroundColor White
    Write-Host "2. Core Temp (simple CPU monitoring)" -ForegroundColor White  
    Write-Host "3. AMD Ryzen Master (official AMD tool)" -ForegroundColor White
    Write-Host "4. Check BIOS temperature readings" -ForegroundColor White
    
    # 温度に関する分析
    Write-Host "`nTemperature Analysis based on shutdown pattern:" -ForegroundColor Red
    Write-Host "- 26 unexpected shutdowns indicate thermal issues" -ForegroundColor White
    Write-Host "- AMD Ryzen 9 6900HX normal temp: <70C under load" -ForegroundColor Green
    Write-Host "- Thermal shutdown occurs around 95C" -ForegroundColor Red
    Write-Host "- Gaming laptops commonly overheat due to dust/poor cooling" -ForegroundColor Yellow
    
    Write-Host "`nImmediate actions needed:" -ForegroundColor Red
    Write-Host "1. Install temperature monitoring software" -ForegroundColor White
    Write-Host "2. Clean laptop fans and heat sinks" -ForegroundColor White
    Write-Host "3. Check thermal paste condition" -ForegroundColor White
    Write-Host "4. Ensure proper ventilation during use" -ForegroundColor White
    
} catch {
    Write-Host "Temperature check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue"