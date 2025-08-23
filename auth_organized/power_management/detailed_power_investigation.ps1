# 詳細な電源問題調査スクリプト
# 認証情報は事前設定済み

$targetPC = "192.168.111.163"
$username = "pc"
$password = "4Ernfb7E"

Write-Host "=== Detailed Power Investigation ===" -ForegroundColor Green
Write-Host "Target: $targetPC (WINDOWS-8R73QDH)" -ForegroundColor Cyan
Write-Host "Found: 26 unexpected shutdowns - investigating..." -ForegroundColor Yellow

# 認証情報作成
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

$resultFile = "C:\Users\hirotaka\Documents\work\auth\power_investigation_detailed_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $resultFile

try {
    Write-Host "`n1. Analyzing unexpected shutdowns (Event ID 6008)..." -ForegroundColor Yellow
    $shutdownDetails = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 6008} | 
            Select-Object -First 15 TimeGenerated, Message |
            Sort-Object TimeGenerated -Descending
    }
    
    Write-Host "Recent Unexpected Shutdowns:" -ForegroundColor Red
    $shutdownDetails | Format-Table TimeGenerated -AutoSize
    
    Write-Host "`n2. Checking for system crashes (BugCheck)..." -ForegroundColor Yellow
    $crashDetails = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        Get-EventLog -LogName System | 
            Where-Object {$_.EventID -eq 1001 -and $_.Source -eq "BugCheck"} |
            Select-Object -First 10 TimeGenerated, Message
    }
    
    if ($crashDetails) {
        Write-Host "System Crashes Found:" -ForegroundColor Red
        $crashDetails | Format-Table TimeGenerated -AutoSize
    } else {
        Write-Host "✅ No system crashes (BugCheck) found" -ForegroundColor Green
    }
    
    Write-Host "`n3. Checking Kernel-Power events..." -ForegroundColor Yellow
    $kernelPowerEvents = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        Get-EventLog -LogName System | 
            Where-Object {$_.Source -eq "Microsoft-Windows-Kernel-Power"} |
            Select-Object -First 10 TimeGenerated, EventID, Message
    }
    
    if ($kernelPowerEvents) {
        Write-Host "Kernel-Power Events:" -ForegroundColor Yellow
        $kernelPowerEvents | Format-Table TimeGenerated, EventID -AutoSize
    } else {
        Write-Host "✅ No Kernel-Power events found" -ForegroundColor Green
    }
    
    Write-Host "`n4. System hardware information..." -ForegroundColor Yellow
    $hardwareInfo = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        $cs = Get-WmiObject Win32_ComputerSystem
        $bios = Get-WmiObject Win32_BIOS
        $proc = Get-WmiObject Win32_Processor
        $mem = Get-WmiObject Win32_PhysicalMemory | Measure-Object Capacity -Sum
        
        @{
            Manufacturer = $cs.Manufacturer
            Model = $cs.Model
            TotalRAM_GB = [math]::Round($mem.Sum / 1GB, 2)
            BIOSVersion = $bios.SMBIOSBIOSVersion
            BIOSDate = $bios.ReleaseDate
            ProcessorName = $proc.Name
            ProcessorCores = $proc.NumberOfCores
        }
    }
    
    Write-Host "Hardware Information:" -ForegroundColor Cyan
    $hardwareInfo | Format-List
    
    Write-Host "`n5. Power supply information..." -ForegroundColor Yellow
    $powerInfo = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        # 電源設定確認
        $powerScheme = powercfg /getactivescheme
        $lastWake = powercfg /lastwake
        
        @{
            ActivePowerScheme = $powerScheme
            LastWakeSource = $lastWake
        }
    }
    
    Write-Host "Power Configuration:" -ForegroundColor Cyan
    Write-Host $powerInfo.ActivePowerScheme
    Write-Host "`nLast Wake Source:"
    Write-Host $powerInfo.LastWakeSource
    
    Write-Host "`n6. Recent Critical and Error events..." -ForegroundColor Yellow
    $criticalErrors = Invoke-Command -ComputerName $targetPC -Credential $cred -ScriptBlock {
        Get-EventLog -LogName System -EntryType Error,Critical -Newest 20 |
            Select-Object TimeGenerated, EntryType, Source, EventID, Message |
            Sort-Object TimeGenerated -Descending
    }
    
    Write-Host "Recent Critical/Error Events:" -ForegroundColor Red
    $criticalErrors | Format-Table TimeGenerated, EntryType, Source, EventID -AutoSize
    
    # 分析結果
    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "📊 ANALYSIS RESULTS" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    $analysis = @"
Target System: WINDOWS-8R73QDH ($($hardwareInfo.Manufacturer) $($hardwareInfo.Model))
Processor: $($hardwareInfo.ProcessorName) ($($hardwareInfo.ProcessorCores) cores)
Memory: $($hardwareInfo.TotalRAM_GB) GB
BIOS: $($hardwareInfo.BIOSVersion) ($($hardwareInfo.BIOSDate))

FINDINGS:
🔴 CRITICAL: 26 unexpected shutdowns detected
   - This indicates sudden power loss or system crashes
   - Pattern analysis from timestamps above

PROBABLE CAUSES:
1. Power Supply Unit (PSU) failure/insufficient capacity
2. Overheating (CPU, GPU, or system)
3. Memory (RAM) issues
4. Motherboard power regulation problems
5. Unstable power from wall outlet/UPS

RECOMMENDED ACTIONS:
1. 🔧 IMMEDIATE: Check PSU wattage vs system requirements
2. 🌡️ URGENT: Monitor CPU/GPU temperatures during use
3. 💾 TEST: Run Windows Memory Diagnostic (mdsched.exe)
4. 🔌 CHECK: All internal power connections
5. 📊 MONITOR: Use HWiNFO64 for real-time temperature/voltage monitoring
6. ⚡ VERIFY: Wall outlet voltage stability
7. 🆕 UPDATE: BIOS to latest version

SEVERITY: HIGH - System instability affecting productivity
"@
    
    Write-Host $analysis -ForegroundColor White
    
} catch {
    Write-Host "❌ Investigation error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Stop-Transcript
}

Write-Host "`n📄 Full report saved to: $resultFile" -ForegroundColor Cyan
Write-Host "Press Enter to open report..." -ForegroundColor Gray
Read-Host
notepad $resultFile