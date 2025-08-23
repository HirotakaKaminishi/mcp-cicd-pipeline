# MCP Server Resource Usage Check Script
# MCPサーバー (192.168.111.200) のリソース使用率確認

Write-Host "=== MCP SERVER RESOURCE USAGE CHECK ===" -ForegroundColor Green
Write-Host "Target: 192.168.111.200 (MCP Server)" -ForegroundColor Cyan

# 1. MCP Server Health Check via HTTP
Write-Host "`n[1] Checking MCP Server Status..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://192.168.111.200:8080/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ MCP Server is responding" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ MCP Server not responding on port 8080" -ForegroundColor Red
}

# 2. Check if running locally
Write-Host "`n[2] Checking Local System Resources..." -ForegroundColor Yellow

# CPU Usage
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
Write-Host "CPU Usage: $($cpu.LoadPercentage)%" -ForegroundColor $(if($cpu.LoadPercentage -gt 80){"Red"}elseif($cpu.LoadPercentage -gt 50){"Yellow"}else{"Green"})
Write-Host "CPU Speed: $($cpu.CurrentClockSpeed) MHz / $($cpu.MaxClockSpeed) MHz" -ForegroundColor Cyan

# Memory Usage
$os = Get-CimInstance Win32_OperatingSystem
$totalMem = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
$freeMem = [math]::Round($os.FreePhysicalMemory/1MB, 2)
$usedMem = $totalMem - $freeMem
$memPercent = [math]::Round(($usedMem/$totalMem)*100, 1)

Write-Host "Memory Usage: $usedMem GB / $totalMem GB ($memPercent%)" -ForegroundColor $(if($memPercent -gt 80){"Red"}elseif($memPercent -gt 60){"Yellow"}else{"Green"})

# 3. Docker Container Status (if MCP runs in Docker)
Write-Host "`n[3] Checking Docker Containers..." -ForegroundColor Yellow
try {
    $dockerPs = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null
    if ($dockerPs) {
        Write-Host $dockerPs -ForegroundColor Cyan
        
        # Get container stats
        $dockerStats = docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>$null
        if ($dockerStats) {
            Write-Host "`nContainer Resource Usage:" -ForegroundColor Yellow
            Write-Host $dockerStats -ForegroundColor Cyan
        }
    } else {
        Write-Host "No Docker containers running" -ForegroundColor Gray
    }
} catch {
    Write-Host "Docker not available or not running" -ForegroundColor Gray
}

# 4. Network Connection to MCP Server
Write-Host "`n[4] Network Connection Test..." -ForegroundColor Yellow
$pingResult = Test-Connection -ComputerName 192.168.111.200 -Count 2 -Quiet
if ($pingResult) {
    Write-Host "✓ Network connection to MCP Server is OK" -ForegroundColor Green
    
    # Test specific ports
    $ports = @(8080, 80, 22, 3001)
    foreach ($port in $ports) {
        $tcpTest = Test-NetConnection -ComputerName 192.168.111.200 -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Host "Port $port : $(if($tcpTest){'✓ Open'}else{'✗ Closed'})" -ForegroundColor $(if($tcpTest){"Green"}else{"Red"})
    }
} else {
    Write-Host "✗ Cannot reach MCP Server" -ForegroundColor Red
}

# 5. Process Check for MCP-related services
Write-Host "`n[5] Checking MCP-related Processes..." -ForegroundColor Yellow
$mcpProcesses = Get-Process | Where-Object {$_.ProcessName -match "node|python|mcp|docker"} | 
    Select-Object ProcessName, CPU, WorkingSet, Id | 
    Sort-Object CPU -Descending | 
    Select-Object -First 10

if ($mcpProcesses) {
    Write-Host "MCP-related processes:" -ForegroundColor Cyan
    $mcpProcesses | Format-Table -AutoSize
} else {
    Write-Host "No MCP-related processes found" -ForegroundColor Gray
}

# 6. Disk Usage
Write-Host "`n[6] Disk Usage..." -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Used -gt 0} | ForEach-Object {
    $usedGB = [math]::Round($_.Used/1GB, 2)
    $freeGB = [math]::Round($_.Free/1GB, 2)
    $totalGB = $usedGB + $freeGB
    $percentUsed = [math]::Round(($usedGB/$totalGB)*100, 1)
    
    Write-Host "$($_.Name): Drive - $usedGB GB / $totalGB GB ($percentUsed% used)" -ForegroundColor $(if($percentUsed -gt 90){"Red"}elseif($percentUsed -gt 70){"Yellow"}else{"Green"})
}

Write-Host "`n=== RESOURCE USAGE SUMMARY ===" -ForegroundColor Green
Write-Host "CPU: $($cpu.LoadPercentage)%" -ForegroundColor $(if($cpu.LoadPercentage -gt 80){"Red"}elseif($cpu.LoadPercentage -gt 50){"Yellow"}else{"Green"})
Write-Host "Memory: $memPercent%" -ForegroundColor $(if($memPercent -gt 80){"Red"}elseif($memPercent -gt 60){"Yellow"}else{"Green"})
Write-Host "MCP Server: $(if($pingResult){'Reachable'}else{'Unreachable'})" -ForegroundColor $(if($pingResult){"Green"}else{"Red"})