# 詳細システムスペック確認スクリプト

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "======================================" -ForegroundColor Green
Write-Host "    DETAILED SYSTEM SPECIFICATIONS" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target: $targetPC (WINDOWS-8R73QDH)" -ForegroundColor Cyan

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

try {
    Write-Host "`nGathering comprehensive system information..." -ForegroundColor Yellow
    
    $systemSpecs = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $specs = @{}
        
        # コンピュータシステム情報
        $computer = Get-WmiObject Win32_ComputerSystem
        $specs.ComputerName = $computer.Name
        $specs.Manufacturer = $computer.Manufacturer
        $specs.Model = $computer.Model
        $specs.SystemType = $computer.SystemType
        $specs.TotalPhysicalMemoryGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
        
        # CPU詳細情報
        $cpu = Get-WmiObject Win32_Processor
        $specs.CPUName = $cpu.Name
        $specs.CPUManufacturer = $cpu.Manufacturer
        $specs.CPUFamily = $cpu.Family
        $specs.CPUModel = $cpu.Model
        $specs.CPUStepping = $cpu.Stepping
        $specs.CPUCores = $cpu.NumberOfCores
        $specs.CPULogicalProcessors = $cpu.NumberOfLogicalProcessors
        $specs.CPUMaxClockSpeedMHz = $cpu.MaxClockSpeed
        $specs.CPUCurrentClockSpeedMHz = $cpu.CurrentClockSpeed
        $specs.CPUArchitecture = switch ($cpu.Architecture) {
            0 { "x86" }
            1 { "MIPS" }
            2 { "Alpha" }
            3 { "PowerPC" }
            6 { "ia64" }
            9 { "x64" }
            default { "Unknown ($($cpu.Architecture))" }
        }
        $specs.CPUAddressWidth = $cpu.AddressWidth
        $specs.CPUDataWidth = $cpu.DataWidth
        
        # OS情報
        $os = Get-WmiObject Win32_OperatingSystem
        $specs.OSName = $os.Caption
        $specs.OSVersion = $os.Version
        $specs.OSBuildNumber = $os.BuildNumber
        $specs.OSArchitecture = $os.OSArchitecture
        $specs.OSServicePack = $os.ServicePackMajorVersion
        $specs.OSInstallDate = [Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate)
        $specs.OSLastBootTime = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        
        # メモリ詳細情報
        $memory = Get-WmiObject Win32_PhysicalMemory
        $specs.MemoryModules = @()
        foreach ($module in $memory) {
            $specs.MemoryModules += @{
                Capacity = [math]::Round($module.Capacity / 1GB, 2)
                Speed = $module.Speed
                Manufacturer = $module.Manufacturer
                PartNumber = $module.PartNumber
                DeviceLocator = $module.DeviceLocator
            }
        }
        
        # BIOS/UEFI情報
        $bios = Get-WmiObject Win32_BIOS
        $specs.BIOSManufacturer = $bios.Manufacturer
        $specs.BIOSVersion = $bios.SMBIOSBIOSVersion
        $specs.BIOSReleaseDate = if ($bios.ReleaseDate) { 
            [Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate) 
        } else { 
            "Unknown" 
        }
        
        # マザーボード情報
        $motherboard = Get-WmiObject Win32_BaseBoard
        $specs.MotherboardManufacturer = $motherboard.Manufacturer
        $specs.MotherboardProduct = $motherboard.Product
        $specs.MotherboardVersion = $motherboard.Version
        
        # グラフィックス情報
        $graphics = Get-WmiObject Win32_VideoController
        $specs.GraphicsCards = @()
        foreach ($gpu in $graphics) {
            $specs.GraphicsCards += @{
                Name = $gpu.Name
                AdapterRAM = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB, 2) } else { "Unknown" }
                DriverVersion = $gpu.DriverVersion
                DriverDate = $gpu.DriverDate
            }
        }
        
        # ストレージ情報
        $disks = Get-WmiObject Win32_DiskDrive
        $specs.StorageDevices = @()
        foreach ($disk in $disks) {
            $specs.StorageDevices += @{
                Model = $disk.Model
                Size = [math]::Round($disk.Size / 1GB, 2)
                InterfaceType = $disk.InterfaceType
                MediaType = $disk.MediaType
            }
        }
        
        # ネットワークアダプター情報
        $network = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true }
        $specs.NetworkAdapters = @()
        foreach ($adapter in $network) {
            $specs.NetworkAdapters += @{
                Name = $adapter.Name
                Manufacturer = $adapter.Manufacturer
                MACAddress = $adapter.MACAddress
                Speed = $adapter.Speed
            }
        }
        
        # 電源プラン情報
        $activePlan = powercfg /getactivescheme
        $specs.ActivePowerPlan = $activePlan
        
        # 現在のシステム状態
        $specs.CurrentTime = Get-Date
        $uptime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        $specs.Uptime = "$($uptime.Hours)h $($uptime.Minutes)m"
        
        return $specs
    }
    
    # 詳細情報表示
    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "                    SYSTEM OVERVIEW" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    Write-Host "`n🖥️ Computer Information:" -ForegroundColor Cyan
    Write-Host "  Computer Name: $($systemSpecs.ComputerName)" -ForegroundColor White
    Write-Host "  Manufacturer: $($systemSpecs.Manufacturer)" -ForegroundColor White
    Write-Host "  Model: $($systemSpecs.Model)" -ForegroundColor White
    Write-Host "  System Type: $($systemSpecs.SystemType)" -ForegroundColor White
    Write-Host "  Current Time: $($systemSpecs.CurrentTime)" -ForegroundColor White
    Write-Host "  Uptime: $($systemSpecs.Uptime)" -ForegroundColor White
    
    Write-Host "`n🔥 CPU Specifications:" -ForegroundColor Cyan
    Write-Host "  Processor: $($systemSpecs.CPUName)" -ForegroundColor White
    Write-Host "  Manufacturer: $($systemSpecs.CPUManufacturer)" -ForegroundColor White
    Write-Host "  Architecture: $($systemSpecs.CPUArchitecture)" -ForegroundColor White
    Write-Host "  Physical Cores: $($systemSpecs.CPUCores)" -ForegroundColor White
    Write-Host "  Logical Processors: $($systemSpecs.CPULogicalProcessors)" -ForegroundColor White
    Write-Host "  Max Clock Speed: $($systemSpecs.CPUMaxClockSpeedMHz) MHz" -ForegroundColor White
    Write-Host "  Current Clock Speed: $($systemSpecs.CPUCurrentClockSpeedMHz) MHz" -ForegroundColor White
    Write-Host "  Address Width: $($systemSpecs.CPUAddressWidth) bit" -ForegroundColor White
    Write-Host "  Data Width: $($systemSpecs.CPUDataWidth) bit" -ForegroundColor White
    
    Write-Host "`n💾 Memory Information:" -ForegroundColor Cyan
    Write-Host "  Total Physical Memory: $($systemSpecs.TotalPhysicalMemoryGB) GB" -ForegroundColor White
    Write-Host "  Memory Modules:" -ForegroundColor White
    foreach ($module in $systemSpecs.MemoryModules) {
        Write-Host "    - $($module.Capacity) GB @ $($module.Speed) MHz ($($module.DeviceLocator))" -ForegroundColor Gray
        Write-Host "      Manufacturer: $($module.Manufacturer), Part: $($module.PartNumber)" -ForegroundColor Gray
    }
    
    Write-Host "`n🖥️ Operating System:" -ForegroundColor Cyan
    Write-Host "  OS: $($systemSpecs.OSName)" -ForegroundColor White
    Write-Host "  Version: $($systemSpecs.OSVersion)" -ForegroundColor White
    Write-Host "  Build: $($systemSpecs.OSBuildNumber)" -ForegroundColor White
    Write-Host "  Architecture: $($systemSpecs.OSArchitecture)" -ForegroundColor White
    Write-Host "  Install Date: $($systemSpecs.OSInstallDate)" -ForegroundColor White
    Write-Host "  Last Boot: $($systemSpecs.OSLastBootTime)" -ForegroundColor White
    
    Write-Host "`n⚡ BIOS/UEFI Information:" -ForegroundColor Cyan
    Write-Host "  Manufacturer: $($systemSpecs.BIOSManufacturer)" -ForegroundColor White
    Write-Host "  Version: $($systemSpecs.BIOSVersion)" -ForegroundColor White
    Write-Host "  Release Date: $($systemSpecs.BIOSReleaseDate)" -ForegroundColor White
    
    Write-Host "`n🔧 Motherboard:" -ForegroundColor Cyan
    Write-Host "  Manufacturer: $($systemSpecs.MotherboardManufacturer)" -ForegroundColor White
    Write-Host "  Product: $($systemSpecs.MotherboardProduct)" -ForegroundColor White
    Write-Host "  Version: $($systemSpecs.MotherboardVersion)" -ForegroundColor White
    
    Write-Host "`n🎮 Graphics Cards:" -ForegroundColor Cyan
    foreach ($gpu in $systemSpecs.GraphicsCards) {
        Write-Host "  - $($gpu.Name)" -ForegroundColor White
        Write-Host "    VRAM: $($gpu.AdapterRAM) GB" -ForegroundColor Gray
        Write-Host "    Driver: $($gpu.DriverVersion)" -ForegroundColor Gray
    }
    
    Write-Host "`n💿 Storage Devices:" -ForegroundColor Cyan
    foreach ($disk in $systemSpecs.StorageDevices) {
        Write-Host "  - $($disk.Model)" -ForegroundColor White
        Write-Host "    Size: $($disk.Size) GB, Interface: $($disk.InterfaceType)" -ForegroundColor Gray
    }
    
    Write-Host "`n🌐 Network Adapters:" -ForegroundColor Cyan
    foreach ($adapter in $systemSpecs.NetworkAdapters) {
        Write-Host "  - $($adapter.Name)" -ForegroundColor White
        Write-Host "    MAC: $($adapter.MACAddress), Manufacturer: $($adapter.Manufacturer)" -ForegroundColor Gray
    }
    
    Write-Host "`n⚡ Power Management:" -ForegroundColor Cyan
    Write-Host "  $($systemSpecs.ActivePowerPlan)" -ForegroundColor Green
    
    if ($systemSpecs.ActivePowerPlan -match "Thermal Protection Plan") {
        Write-Host "`n🛡️ THERMAL PROTECTION: ACTIVE" -ForegroundColor Green
        Write-Host "  AMD Ryzen 9 6900HX thermal management enabled" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ THERMAL PROTECTION: NOT ACTIVE" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ System specification gathering failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "            SYSTEM SPECIFICATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue"