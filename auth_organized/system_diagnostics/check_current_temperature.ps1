# 現在の温度確認スクリプト
# 対象PC（192.168.111.163）の温度を取得

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "=== Current Temperature Check ===" -ForegroundColor Green
Write-Host "Target: $targetPC (WINDOWS-8R73QDH)" -ForegroundColor Cyan

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`n🌡️ Checking current temperatures..." -ForegroundColor Yellow
    
    $temperatureData = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $results = @{}
        
        # 方法1: WMI温度センサー
        try {
            $temps = Get-WmiObject -Namespace "root/WMI" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($temps) {
                $results.WMI_Temperatures = @()
                foreach ($temp in $temps) {
                    $celsius = ($temp.CurrentTemperature - 2732) / 10
                    $results.WMI_Temperatures += "Zone $($temp.InstanceName): $celsius°C"
                }
            } else {
                $results.WMI_Temperatures = "No WMI temperature sensors found"
            }
        } catch {
            $results.WMI_Temperatures = "WMI temperature access failed: $($_.Exception.Message)"
        }
        
        # 方法2: OpenHardwareMonitor WMI（インストールされている場合）
        try {
            $ohmTemps = Get-WmiObject -Namespace "root/OpenHardwareMonitor" -Class Sensor -ErrorAction SilentlyContinue | 
                       Where-Object {$_.SensorType -eq "Temperature"}
            if ($ohmTemps) {
                $results.OHM_Temperatures = @()
                foreach ($temp in $ohmTemps) {
                    $results.OHM_Temperatures += "$($temp.Name): $($temp.Value)°C"
                }
            } else {
                $results.OHM_Temperatures = "OpenHardwareMonitor not detected"
            }
        } catch {
            $results.OHM_Temperatures = "OpenHardwareMonitor access failed"
        }
        
        # 方法3: WMIC を使用
        try {
            $wmicTemp = wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature /value 2>$null
            if ($wmicTemp) {
                $results.WMIC_Temperature = $wmicTemp | Where-Object {$_ -like "CurrentTemperature=*"}
            } else {
                $results.WMIC_Temperature = "WMIC temperature not available"
            }
        } catch {
            $results.WMIC_Temperature = "WMIC failed"
        }
        
        # 方法4: PowerShell Hardware Info
        try {
            $win32Temp = Get-WmiObject -Class Win32_TemperatureProbe -ErrorAction SilentlyContinue
            if ($win32Temp) {
                $results.Win32_Temperature = @()
                foreach ($probe in $win32Temp) {
                    if ($probe.CurrentReading) {
                        $celsius = ($probe.CurrentReading - 2732) / 10
                        $results.Win32_Temperature += "$($probe.Description): $celsius°C"
                    }
                }
            } else {
                $results.Win32_Temperature = "Win32_TemperatureProbe not available"
            }
        } catch {
            $results.Win32_Temperature = "Win32_TemperatureProbe failed"
        }
        
        # 方法5: CPU使用率（間接的な負荷指標）
        try {
            $cpu = Get-WmiObject Win32_Processor
            $results.CPU_Usage = "CPU Usage: $($cpu.LoadPercentage)%"
        } catch {
            $results.CPU_Usage = "CPU usage not available"
        }
        
        # 方法6: システム時間とアップタイム
        $uptime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime)
        $results.System_Info = @{
            CurrentTime = Get-Date
            Uptime = "$($uptime.Days)日 $($uptime.Hours)時間 $($uptime.Minutes)分"
            LastBoot = [Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime)
        }
        
        return $results
    }
    
    # 結果表示
    Write-Host "`n📊 Temperature Results:" -ForegroundColor Cyan
    Write-Host "=" * 50
    
    # WMI温度
    Write-Host "`n🌡️ WMI Temperature Sensors:" -ForegroundColor Yellow
    if ($temperatureData.WMI_Temperatures -is [array]) {
        foreach ($temp in $temperatureData.WMI_Temperatures) {
            Write-Host "  $temp" -ForegroundColor White
        }
    } else {
        Write-Host "  $($temperatureData.WMI_Temperatures)" -ForegroundColor Gray
    }
    
    # OpenHardwareMonitor
    Write-Host "`n🔧 OpenHardwareMonitor:" -ForegroundColor Yellow
    if ($temperatureData.OHM_Temperatures -is [array]) {
        foreach ($temp in $temperatureData.OHM_Temperatures) {
            Write-Host "  $temp" -ForegroundColor White
        }
    } else {
        Write-Host "  $($temperatureData.OHM_Temperatures)" -ForegroundColor Gray
    }
    
    # WMIC結果
    Write-Host "`n💻 WMIC Temperature:" -ForegroundColor Yellow
    Write-Host "  $($temperatureData.WMIC_Temperature)" -ForegroundColor Gray
    
    # Win32温度プローブ
    Write-Host "`n🔍 Win32 Temperature Probes:" -ForegroundColor Yellow
    if ($temperatureData.Win32_Temperature -is [array]) {
        foreach ($temp in $temperatureData.Win32_Temperature) {
            Write-Host "  $temp" -ForegroundColor White
        }
    } else {
        Write-Host "  $($temperatureData.Win32_Temperature)" -ForegroundColor Gray
    }
    
    # CPU使用率
    Write-Host "`n⚡ System Load:" -ForegroundColor Yellow
    Write-Host "  $($temperatureData.CPU_Usage)" -ForegroundColor White
    
    # システム情報
    Write-Host "`n🕐 System Status:" -ForegroundColor Yellow
    Write-Host "  Current Time: $($temperatureData.System_Info.CurrentTime)" -ForegroundColor White
    Write-Host "  Uptime: $($temperatureData.System_Info.Uptime)" -ForegroundColor White
    Write-Host "  Last Boot: $($temperatureData.System_Info.LastBoot)" -ForegroundColor White
    
    # 温度が検出できない場合の代替手段
    Write-Host "`n⚠️ Alternative Temperature Monitoring:" -ForegroundColor Yellow
    Write-Host "Since direct temperature reading may not be available, consider:" -ForegroundColor Gray
    Write-Host "1. Install HWiNFO64 on target PC for accurate temperature monitoring" -ForegroundColor White
    Write-Host "2. Use Core Temp (free software)" -ForegroundColor White
    Write-Host "3. Check BIOS/UEFI temperature readings" -ForegroundColor White
    Write-Host "4. Use manufacturer-specific software (e.g., AMD Ryzen Master)" -ForegroundColor White
    
    # 温度に基づく推奨事項
    Write-Host "`n🔥 Temperature Analysis:" -ForegroundColor Red
    Write-Host "Given the frequent shutdowns (26 times), temperature is likely the culprit:" -ForegroundColor White
    Write-Host "- Normal CPU temp: < 70°C under load" -ForegroundColor Green
    Write-Host "- Warning range: 70-85°C" -ForegroundColor Yellow
    Write-Host "- Critical range: > 85°C (causes shutdowns)" -ForegroundColor Red
    Write-Host "`nFor AMD Ryzen 9 6900HX: Tjmax = 95°C (thermal shutdown)" -ForegroundColor Red
    
} catch {
    Write-Host "❌ Temperature check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host