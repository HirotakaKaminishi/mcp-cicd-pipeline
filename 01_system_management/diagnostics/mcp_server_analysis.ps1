# MCP Server Comprehensive Analysis Script

$mcpServerIP = "192.168.111.200"
$mcpServerURL = "http://192.168.111.200:8080"

Write-Host "======================================" -ForegroundColor Green
Write-Host "    MCP SERVER ANALYSIS TOOL" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target MCP Server: $mcpServerIP" -ForegroundColor Cyan
Write-Host "Service URL: $mcpServerURL" -ForegroundColor Cyan

try {
    Write-Host "`n🔍 Phase 1: Network Connectivity Analysis..." -ForegroundColor Yellow
    
    # Test basic network connectivity
    $networkTest = @{}
    
    # Ping test
    Write-Host "Testing basic network connectivity..." -ForegroundColor Cyan
    $pingResult = Test-Connection -ComputerName $mcpServerIP -Count 4 -ErrorAction SilentlyContinue
    if ($pingResult) {
        $avgResponseTime = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
        $networkTest.PingStatus = "Success"
        $networkTest.AvgResponseTime = [math]::Round($avgResponseTime, 2)
        $networkTest.PacketLoss = 0
        Write-Host "  ✅ Ping successful - Avg response: $($networkTest.AvgResponseTime) ms" -ForegroundColor Green
    } else {
        $networkTest.PingStatus = "Failed"
        $networkTest.AvgResponseTime = "N/A"
        Write-Host "  ❌ Ping failed - Server may be offline" -ForegroundColor Red
    }
    
    # Port connectivity tests
    Write-Host "`nTesting port connectivity..." -ForegroundColor Cyan
    $ports = @(8080, 80, 22, 3001)
    $networkTest.PortStatus = @{}
    
    foreach ($port in $ports) {
        try {
            $tcpTest = Test-NetConnection -ComputerName $mcpServerIP -Port $port -WarningAction SilentlyContinue
            $networkTest.PortStatus[$port] = $tcpTest.TcpTestSucceeded
            $status = if ($tcpTest.TcpTestSucceeded) { "Open" } else { "Closed" }
            $color = if ($tcpTest.TcpTestSucceeded) { "Green" } else { "Red" }
            Write-Host "  Port $port`: $status" -ForegroundColor $color
        } catch {
            $networkTest.PortStatus[$port] = $false
            Write-Host "  Port $port`: Failed to test" -ForegroundColor Red
        }
    }
    
    # HTTP service test
    Write-Host "`nTesting MCP HTTP service..." -ForegroundColor Cyan
    try {
        $httpResponse = Invoke-WebRequest -Uri $mcpServerURL -Method GET -TimeoutSec 10 -ErrorAction Stop
        $networkTest.HTTPStatus = $httpResponse.StatusCode
        $networkTest.HTTPResponseTime = "Available"
        Write-Host "  ✅ HTTP service responding - Status: $($httpResponse.StatusCode)" -ForegroundColor Green
    } catch {
        $networkTest.HTTPStatus = "Failed"
        $networkTest.HTTPResponseTime = "N/A"
        Write-Host "  ❌ HTTP service not responding - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n📊 Network Analysis Results:" -ForegroundColor Cyan
    Write-Host "  Ping Status: $($networkTest.PingStatus)" -ForegroundColor $(if ($networkTest.PingStatus -eq "Success") { "Green" } else { "Red" })
    if ($networkTest.AvgResponseTime -ne "N/A") {
        Write-Host "  Average Response Time: $($networkTest.AvgResponseTime) ms" -ForegroundColor White
    }
    Write-Host "  HTTP Service: $($networkTest.HTTPStatus)" -ForegroundColor $(if ($networkTest.HTTPStatus -eq 200) { "Green" } else { "Red" })
    
    # Try to gather system information if accessible
    if ($networkTest.PingStatus -eq "Success") {
        Write-Host "`n🔍 Phase 2: Attempting System Information Gathering..." -ForegroundColor Yellow
        
        # Try SSH connection (if available)
        Write-Host "Checking SSH accessibility..." -ForegroundColor Cyan
        if ($networkTest.PortStatus[22]) {
            Write-Host "  ✅ SSH port (22) is accessible" -ForegroundColor Green
            Write-Host "  📝 Note: SSH authentication would be required for detailed analysis" -ForegroundColor Yellow
        } else {
            Write-Host "  ❌ SSH port (22) is not accessible" -ForegroundColor Red
        }
        
        # Try to get basic info from HTTP headers
        if ($networkTest.HTTPStatus -eq 200) {
            Write-Host "`nAnalyzing HTTP response headers..." -ForegroundColor Cyan
            try {
                $headers = $httpResponse.Headers
                if ($headers.Server) {
                    Write-Host "  Server: $($headers.Server)" -ForegroundColor White
                }
                if ($headers."X-Powered-By") {
                    Write-Host "  Powered By: $($headers.'X-Powered-By')" -ForegroundColor White
                }
                Write-Host "  Content Length: $($httpResponse.RawContentLength) bytes" -ForegroundColor White
            } catch {
                Write-Host "  Could not analyze headers" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "`n🔍 Phase 3: MCP API Analysis..." -ForegroundColor Yellow
    
    # Test MCP API endpoints if HTTP is working
    if ($networkTest.HTTPStatus -eq 200) {
        $apiEndpoints = @(
            "/api/status",
            "/api/health", 
            "/api/system",
            "/health",
            "/status",
            "/"
        )
        
        $mcpAPI = @{}
        Write-Host "Testing common API endpoints..." -ForegroundColor Cyan
        
        foreach ($endpoint in $apiEndpoints) {
            try {
                $apiURL = "$mcpServerURL$endpoint"
                $apiResponse = Invoke-WebRequest -Uri $apiURL -Method GET -TimeoutSec 5 -ErrorAction Stop
                $mcpAPI[$endpoint] = @{
                    Status = $apiResponse.StatusCode
                    ContentLength = $apiResponse.RawContentLength
                    ContentType = $apiResponse.Headers.'Content-Type'
                }
                Write-Host "  ✅ $endpoint - Status: $($apiResponse.StatusCode)" -ForegroundColor Green
                
                # Try to parse JSON response for system info
                if ($apiResponse.Headers.'Content-Type' -like "*json*") {
                    try {
                        $jsonContent = $apiResponse.Content | ConvertFrom-Json
                        if ($jsonContent.system) {
                            Write-Host "    📊 System info detected in response" -ForegroundColor Cyan
                        }
                        if ($jsonContent.version) {
                            Write-Host "    📋 Version: $($jsonContent.version)" -ForegroundColor White
                        }
                    } catch {
                        # JSON parsing failed, that's okay
                    }
                }
            } catch {
                $mcpAPI[$endpoint] = @{
                    Status = "Failed"
                    Error = $_.Exception.Message
                }
                Write-Host "  ❌ $endpoint - Not available" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "              MCP SERVER ANALYSIS SUMMARY" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    # Generate analysis summary
    $analysisScore = 0
    $maxScore = 100
    
    # Network connectivity (40 points)
    Write-Host "`n🌐 NETWORK CONNECTIVITY:" -ForegroundColor Cyan
    if ($networkTest.PingStatus -eq "Success") {
        Write-Host "  ✅ Basic connectivity: WORKING" -ForegroundColor Green
        $analysisScore += 20
        if ($networkTest.AvgResponseTime -lt 50) {
            Write-Host "  ✅ Network latency: EXCELLENT ($($networkTest.AvgResponseTime) ms)" -ForegroundColor Green
            $analysisScore += 10
        } elseif ($networkTest.AvgResponseTime -lt 100) {
            Write-Host "  ⚠️  Network latency: GOOD ($($networkTest.AvgResponseTime) ms)" -ForegroundColor Yellow
            $analysisScore += 7
        } else {
            Write-Host "  ❌ Network latency: HIGH ($($networkTest.AvgResponseTime) ms)" -ForegroundColor Red
            $analysisScore += 3
        }
    } else {
        Write-Host "  ❌ Basic connectivity: FAILED" -ForegroundColor Red
        $analysisScore += 0
    }
    
    # Port accessibility (20 points)
    $openPorts = ($networkTest.PortStatus.Values | Where-Object { $_ -eq $true }).Count
    $totalPorts = $networkTest.PortStatus.Count
    if ($openPorts -eq $totalPorts) {
        Write-Host "  ✅ Port accessibility: ALL PORTS OPEN ($openPorts/$totalPorts)" -ForegroundColor Green
        $analysisScore += 20
    } elseif ($openPorts -gt 0) {
        Write-Host "  ⚠️  Port accessibility: PARTIAL ($openPorts/$totalPorts)" -ForegroundColor Yellow
        $analysisScore += 10
    } else {
        Write-Host "  ❌ Port accessibility: ALL PORTS CLOSED" -ForegroundColor Red
        $analysisScore += 0
    }
    
    # HTTP service (25 points)
    Write-Host "`n🔧 HTTP SERVICE:" -ForegroundColor Cyan
    if ($networkTest.HTTPStatus -eq 200) {
        Write-Host "  ✅ MCP HTTP service: OPERATIONAL" -ForegroundColor Green
        $analysisScore += 25
    } elseif ($networkTest.HTTPStatus -ne "Failed") {
        Write-Host "  ⚠️  MCP HTTP service: RESPONDING (Status: $($networkTest.HTTPStatus))" -ForegroundColor Yellow
        $analysisScore += 15
    } else {
        Write-Host "  ❌ MCP HTTP service: NOT RESPONDING" -ForegroundColor Red
        $analysisScore += 0
    }
    
    # SSH accessibility (15 points)
    Write-Host "`n🔐 REMOTE ACCESS:" -ForegroundColor Cyan
    if ($networkTest.PortStatus[22]) {
        Write-Host "  ✅ SSH access: AVAILABLE" -ForegroundColor Green
        $analysisScore += 15
    } else {
        Write-Host "  ❌ SSH access: NOT AVAILABLE" -ForegroundColor Red
        $analysisScore += 0
    }
    
    # Overall assessment
    $analysisPercentage = [math]::Round(($analysisScore / $maxScore) * 100, 1)
    $assessmentLevel = if ($analysisPercentage -ge 80) { "EXCELLENT" } elseif ($analysisPercentage -ge 60) { "GOOD" } elseif ($analysisPercentage -ge 40) { "FAIR" } else { "POOR" }
    $scoreColor = if ($analysisPercentage -ge 80) { "Green" } elseif ($analysisPercentage -ge 60) { "Yellow" } else { "Red" }
    
    Write-Host "`n🎯 OVERALL MCP SERVER STATUS: $analysisPercentage% - $assessmentLevel" -ForegroundColor $scoreColor
    Write-Host "   ($analysisScore / $maxScore points)" -ForegroundColor White
    
    # Recommendations
    Write-Host "`n📋 ANALYSIS FINDINGS:" -ForegroundColor Cyan
    
    if ($networkTest.PingStatus -eq "Success") {
        Write-Host "  ✅ MCP Server is reachable and responsive" -ForegroundColor Green
    } else {
        Write-Host "  ❌ MCP Server connectivity issues detected" -ForegroundColor Red
    }
    
    if ($networkTest.HTTPStatus -eq 200) {
        Write-Host "  ✅ MCP HTTP service is operational on port 8080" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  MCP HTTP service needs investigation" -ForegroundColor Yellow
    }
    
    if ($networkTest.PortStatus[22]) {
        Write-Host "  ✅ SSH access available for detailed system analysis" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  SSH access not available - limited remote analysis possible" -ForegroundColor Yellow
    }
    
    Write-Host "`n🔧 RECOMMENDED NEXT STEPS:" -ForegroundColor Cyan
    if ($analysisPercentage -ge 80) {
        Write-Host "  • MCP Server appears healthy and operational" -ForegroundColor White
        Write-Host "  • Consider detailed SSH-based analysis for full specs" -ForegroundColor White
        Write-Host "  • Monitor performance and resource usage" -ForegroundColor White
    } elseif ($analysisPercentage -ge 40) {
        Write-Host "  • Address connectivity issues identified" -ForegroundColor White
        Write-Host "  • Check firewall and network configuration" -ForegroundColor White
        Write-Host "  • Verify MCP service status" -ForegroundColor White
    } else {
        Write-Host "  • CRITICAL: MCP Server requires immediate attention" -ForegroundColor Red
        Write-Host "  • Check server power and network connectivity" -ForegroundColor Red
        Write-Host "  • Verify server hardware status" -ForegroundColor Red
    }
    
    # Create analysis report
    $reportContent = @"
# MCP Server Analysis Report

## Analysis Date
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Target Server
- **IP Address**: $mcpServerIP
- **Service URL**: $mcpServerURL
- **Analysis Score**: $analysisPercentage% ($assessmentLevel)

## Network Connectivity
- **Ping Status**: $($networkTest.PingStatus)
- **Average Response Time**: $($networkTest.AvgResponseTime) ms
- **HTTP Service**: $($networkTest.HTTPStatus)

## Port Accessibility
$(foreach ($port in $networkTest.PortStatus.Keys) {
    $status = if ($networkTest.PortStatus[$port]) { "Open" } else { "Closed"} 
    "- **Port $port**: $status"
})

## Service Analysis
- **MCP HTTP Service**: $(if ($networkTest.HTTPStatus -eq 200) { "Operational" } else { "Needs Investigation" })
- **SSH Access**: $(if ($networkTest.PortStatus[22]) { "Available" } else { "Not Available" })

## Recommendations
$(if ($analysisPercentage -ge 80) {
    "✅ MCP Server is healthy and operational`n✅ Ready for production workloads`n• Consider performance monitoring setup"
} elseif ($analysisPercentage -ge 40) {
    "⚠️ Partial connectivity detected`n• Address network/firewall issues`n• Verify service configurations"
} else {
    "❌ Critical issues detected`n• Immediate investigation required`n• Check server hardware and network"
})

## Next Steps
1. Address identified connectivity issues
2. Set up comprehensive monitoring
3. Establish SSH access for detailed analysis
4. Implement health checks and alerting

---
*Generated by MCP Server Analysis Tool*
"@
    
    $reportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "reports\mcp_server_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    # Ensure reports directory exists
    $reportsDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host "`n📝 Analysis report saved: $reportPath" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ MCP Server analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "            MCP SERVER ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue"