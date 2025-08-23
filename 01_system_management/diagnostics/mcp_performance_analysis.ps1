# MCP Server Performance & Load Analysis Script

$mcpServerIP = "192.168.111.200"
$mcpServerURL = "http://192.168.111.200:8080"

Write-Host "======================================" -ForegroundColor Green
Write-Host "    MCP PERFORMANCE & LOAD ANALYSIS" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target Server: $mcpServerIP" -ForegroundColor Cyan

try {
    Write-Host "`n🔍 Phase 1: Response Time Analysis..." -ForegroundColor Yellow
    
    # Comprehensive response time testing
    Write-Host "Testing response times across all services..." -ForegroundColor Cyan
    
    $performanceResults = @{}
    
    # 1. nginx Web Server Performance (Port 80)
    Write-Host "`n🌐 WEB SERVER PERFORMANCE (Port 80):" -ForegroundColor Cyan
    $webResponseTimes = @()
    $webTestCount = 5
    
    for ($i = 1; $i -le $webTestCount; $i++) {
        try {
            $startTime = Get-Date
            $webResponse = Invoke-WebRequest -Uri "http://$mcpServerIP" -Method GET -TimeoutSec 10 -ErrorAction Stop
            $endTime = Get-Date
            $responseTime = ($endTime - $startTime).TotalMilliseconds
            $webResponseTimes += $responseTime
            Write-Host "  Test $i`: $([math]::Round($responseTime, 2)) ms" -ForegroundColor Green
        } catch {
            Write-Host "  Test $i`: Failed - $($_.Exception.Message)" -ForegroundColor Red
            $webResponseTimes += 9999  # High value for failed requests
        }
    }
    
    $webAvgTime = ($webResponseTimes | Measure-Object -Average).Average
    $webMinTime = ($webResponseTimes | Measure-Object -Minimum).Minimum
    $webMaxTime = ($webResponseTimes | Measure-Object -Maximum).Maximum
    
    $performanceResults.WebServer = @{
        AverageResponseTime = [math]::Round($webAvgTime, 2)
        MinResponseTime = [math]::Round($webMinTime, 2)
        MaxResponseTime = [math]::Round($webMaxTime, 2)
        TestCount = $webTestCount
        SuccessRate = (($webResponseTimes | Where-Object { $_ -lt 9999 }).Count / $webTestCount * 100)
    }
    
    Write-Host "  📊 Average: $([math]::Round($webAvgTime, 2)) ms" -ForegroundColor White
    Write-Host "  📊 Min/Max: $([math]::Round($webMinTime, 2)) ms / $([math]::Round($webMaxTime, 2)) ms" -ForegroundColor White
    Write-Host "  📊 Success Rate: $([math]::Round($performanceResults.WebServer.SuccessRate, 1))%" -ForegroundColor $(if ($performanceResults.WebServer.SuccessRate -gt 90) { "Green" } else { "Yellow" })
    
    # 2. Application Service Performance (Port 3001)
    Write-Host "`n📱 APPLICATION SERVICE PERFORMANCE (Port 3001):" -ForegroundColor Cyan
    $appResponseTimes = @()
    $appTestCount = 5
    
    for ($i = 1; $i -le $appTestCount; $i++) {
        try {
            $startTime = Get-Date
            $appResponse = Invoke-WebRequest -Uri "http://$mcpServerIP`:3001" -Method GET -TimeoutSec 10 -ErrorAction Stop
            $endTime = Get-Date
            $responseTime = ($endTime - $startTime).TotalMilliseconds
            $appResponseTimes += $responseTime
            Write-Host "  Test $i`: $([math]::Round($responseTime, 2)) ms" -ForegroundColor Green
        } catch {
            Write-Host "  Test $i`: Failed - $($_.Exception.Message)" -ForegroundColor Red
            $appResponseTimes += 9999
        }
    }
    
    $appAvgTime = ($appResponseTimes | Measure-Object -Average).Average
    $appMinTime = ($appResponseTimes | Measure-Object -Minimum).Minimum
    $appMaxTime = ($appResponseTimes | Measure-Object -Maximum).Maximum
    
    $performanceResults.AppService = @{
        AverageResponseTime = [math]::Round($appAvgTime, 2)
        MinResponseTime = [math]::Round($appMinTime, 2)
        MaxResponseTime = [math]::Round($appMaxTime, 2)
        TestCount = $appTestCount
        SuccessRate = (($appResponseTimes | Where-Object { $_ -lt 9999 }).Count / $appTestCount * 100)
    }
    
    Write-Host "  📊 Average: $([math]::Round($appAvgTime, 2)) ms" -ForegroundColor White
    Write-Host "  📊 Min/Max: $([math]::Round($appMinTime, 2)) ms / $([math]::Round($appMaxTime, 2)) ms" -ForegroundColor White
    Write-Host "  📊 Success Rate: $([math]::Round($performanceResults.AppService.SuccessRate, 1))%" -ForegroundColor $(if ($performanceResults.AppService.SuccessRate -gt 90) { "Green" } else { "Yellow" })
    
    # 3. Network Latency Analysis
    Write-Host "`n🌐 NETWORK LATENCY ANALYSIS:" -ForegroundColor Cyan
    $pingTests = @()
    $pingTestCount = 10
    
    Write-Host "Performing extended ping analysis ($pingTestCount tests)..." -ForegroundColor Cyan
    for ($i = 1; $i -le $pingTestCount; $i++) {
        try {
            $pingResult = Test-Connection -ComputerName $mcpServerIP -Count 1 -ErrorAction Stop
            $pingTime = $pingResult[0].ResponseTime
            $pingTests += $pingTime
            Write-Host "  Ping $i`: $pingTime ms" -ForegroundColor Green
        } catch {
            Write-Host "  Ping $i`: Failed" -ForegroundColor Red
            $pingTests += 9999
        }
    }
    
    $pingAvgTime = ($pingTests | Where-Object { $_ -lt 9999 } | Measure-Object -Average).Average
    $pingMinTime = ($pingTests | Where-Object { $_ -lt 9999 } | Measure-Object -Minimum).Minimum
    $pingMaxTime = ($pingTests | Where-Object { $_ -lt 9999 } | Measure-Object -Maximum).Maximum
    $pingSuccessRate = (($pingTests | Where-Object { $_ -lt 9999 }).Count / $pingTestCount * 100)
    
    $performanceResults.NetworkLatency = @{
        AverageLatency = if ($pingAvgTime) { [math]::Round($pingAvgTime, 2) } else { "N/A" }
        MinLatency = if ($pingMinTime) { [math]::Round($pingMinTime, 2) } else { "N/A" }
        MaxLatency = if ($pingMaxTime) { [math]::Round($pingMaxTime, 2) } else { "N/A" }
        SuccessRate = [math]::Round($pingSuccessRate, 1)
    }
    
    if ($pingAvgTime) {
        Write-Host "  📊 Average Latency: $([math]::Round($pingAvgTime, 2)) ms" -ForegroundColor White
        Write-Host "  📊 Min/Max Latency: $([math]::Round($pingMinTime, 2)) ms / $([math]::Round($pingMaxTime, 2)) ms" -ForegroundColor White
    }
    Write-Host "  📊 Ping Success Rate: $([math]::Round($pingSuccessRate, 1))%" -ForegroundColor $(if ($pingSuccessRate -gt 95) { "Green" } else { "Yellow" })
    
    Write-Host "`n🔍 Phase 2: Load Testing..." -ForegroundColor Yellow
    
    # Concurrent request testing
    Write-Host "Performing concurrent load testing..." -ForegroundColor Cyan
    
    # Test concurrent requests to web server
    Write-Host "`n⚡ CONCURRENT LOAD TEST (Web Server):" -ForegroundColor Cyan
    $concurrentTests = 3
    $loadTestResults = @()
    
    Write-Host "Sending $concurrentTests concurrent requests..." -ForegroundColor Cyan
    $jobs = @()
    
    for ($i = 1; $i -le $concurrentTests; $i++) {
        $job = Start-Job -ScriptBlock {
            param($serverIP)
            try {
                $startTime = Get-Date
                $response = Invoke-WebRequest -Uri "http://$serverIP" -Method GET -TimeoutSec 15
                $endTime = Get-Date
                $responseTime = ($endTime - $startTime).TotalMilliseconds
                return @{
                    Success = $true
                    ResponseTime = $responseTime
                    StatusCode = $response.StatusCode
                }
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    ResponseTime = 9999
                }
            }
        } -ArgumentList $mcpServerIP
        $jobs += $job
    }
    
    # Wait for all jobs to complete
    $jobs | Wait-Job | Out-Null
    
    foreach ($job in $jobs) {
        $result = Receive-Job $job
        $loadTestResults += $result
        Remove-Job $job
    }
    
    $successfulRequests = ($loadTestResults | Where-Object { $_.Success -eq $true }).Count
    $avgConcurrentTime = ($loadTestResults | Where-Object { $_.Success -eq $true } | Measure-Object -Property ResponseTime -Average).Average
    
    Write-Host "  📊 Concurrent Success Rate: $successfulRequests/$concurrentTests ($([math]::Round($successfulRequests/$concurrentTests*100, 1))%)" -ForegroundColor $(if ($successfulRequests -eq $concurrentTests) { "Green" } else { "Yellow" })
    if ($avgConcurrentTime) {
        Write-Host "  📊 Average Concurrent Response: $([math]::Round($avgConcurrentTime, 2)) ms" -ForegroundColor White
    }
    
    $performanceResults.LoadTest = @{
        ConcurrentRequests = $concurrentTests
        SuccessfulRequests = $successfulRequests
        SuccessRate = [math]::Round($successfulRequests/$concurrentTests*100, 1)
        AverageResponseTime = if ($avgConcurrentTime) { [math]::Round($avgConcurrentTime, 2) } else { "N/A" }
    }
    
    Write-Host "`n🔍 Phase 3: Service Stability Assessment..." -ForegroundColor Yellow
    
    # Stability testing over time
    Write-Host "Assessing service stability over time..." -ForegroundColor Cyan
    
    $stabilityTests = @()
    $stabilityTestCount = 5
    $testInterval = 2  # seconds
    
    Write-Host "`n⏱️  STABILITY TEST (5 tests over 10 seconds):" -ForegroundColor Cyan
    for ($i = 1; $i -le $stabilityTestCount; $i++) {
        try {
            $startTime = Get-Date
            $response = Invoke-WebRequest -Uri "http://$mcpServerIP" -Method GET -TimeoutSec 10 -ErrorAction Stop
            $endTime = Get-Date
            $responseTime = ($endTime - $startTime).TotalMilliseconds
            
            $stabilityTests += @{
                TestNumber = $i
                Success = $true
                ResponseTime = $responseTime
                Timestamp = $startTime
            }
            
            Write-Host "  Stability Test $i`: $([math]::Round($responseTime, 2)) ms - Success" -ForegroundColor Green
        } catch {
            $stabilityTests += @{
                TestNumber = $i
                Success = $false
                Error = $_.Exception.Message
                Timestamp = (Get-Date)
            }
            Write-Host "  Stability Test $i`: Failed - $($_.Exception.Message)" -ForegroundColor Red
        }
        
        if ($i -lt $stabilityTestCount) {
            Start-Sleep -Seconds $testInterval
        }
    }
    
    $stabilitySuccessRate = (($stabilityTests | Where-Object { $_.Success -eq $true }).Count / $stabilityTestCount * 100)
    $performanceResults.Stability = @{
        TestCount = $stabilityTestCount
        SuccessRate = [math]::Round($stabilitySuccessRate, 1)
        TestInterval = $testInterval
    }
    
    Write-Host "  📊 Stability Success Rate: $([math]::Round($stabilitySuccessRate, 1))%" -ForegroundColor $(if ($stabilitySuccessRate -gt 95) { "Green" } else { "Yellow" })
    
    Write-Host "`n🔍 Phase 4: Performance Score Calculation..." -ForegroundColor Yellow
    
    # Calculate comprehensive performance score
    $performanceScore = 0
    $maxScore = 100
    
    # Response Time Score (30 points)
    $responseTimeScore = 0
    if ($webAvgTime -lt 100) { $responseTimeScore = 30 }
    elseif ($webAvgTime -lt 200) { $responseTimeScore = 25 }
    elseif ($webAvgTime -lt 500) { $responseTimeScore = 20 }
    elseif ($webAvgTime -lt 1000) { $responseTimeScore = 15 }
    else { $responseTimeScore = 10 }
    
    # Reliability Score (25 points)
    $reliabilityScore = 0
    $avgSuccessRate = ($performanceResults.WebServer.SuccessRate + $performanceResults.AppService.SuccessRate) / 2
    if ($avgSuccessRate -ge 98) { $reliabilityScore = 25 }
    elseif ($avgSuccessRate -ge 95) { $reliabilityScore = 22 }
    elseif ($avgSuccessRate -ge 90) { $reliabilityScore = 18 }
    elseif ($avgSuccessRate -ge 80) { $reliabilityScore = 15 }
    else { $reliabilityScore = 10 }
    
    # Network Quality Score (20 points)
    $networkScore = 0
    if ($pingAvgTime -and $pingAvgTime -lt 10) { $networkScore = 20 }
    elseif ($pingAvgTime -and $pingAvgTime -lt 20) { $networkScore = 18 }
    elseif ($pingAvgTime -and $pingAvgTime -lt 50) { $networkScore = 15 }
    elseif ($pingAvgTime -and $pingAvgTime -lt 100) { $networkScore = 12 }
    else { $networkScore = 8 }
    
    # Load Handling Score (15 points)
    $loadScore = 0
    if ($performanceResults.LoadTest.SuccessRate -ge 95) { $loadScore = 15 }
    elseif ($performanceResults.LoadTest.SuccessRate -ge 90) { $loadScore = 12 }
    elseif ($performanceResults.LoadTest.SuccessRate -ge 80) { $loadScore = 10 }
    else { $loadScore = 6 }
    
    # Stability Score (10 points)
    $stabilityScore = 0
    if ($stabilitySuccessRate -ge 98) { $stabilityScore = 10 }
    elseif ($stabilitySuccessRate -ge 95) { $stabilityScore = 8 }
    elseif ($stabilitySuccessRate -ge 90) { $stabilityScore = 6 }
    else { $stabilityScore = 4 }
    
    $performanceScore = $responseTimeScore + $reliabilityScore + $networkScore + $loadScore + $stabilityScore
    $performancePercentage = [math]::Round(($performanceScore / $maxScore) * 100, 1)
    $performanceLevel = if ($performancePercentage -ge 85) { "EXCELLENT" } elseif ($performancePercentage -ge 70) { "GOOD" } elseif ($performancePercentage -ge 55) { "FAIR" } else { "POOR" }
    $scoreColor = if ($performancePercentage -ge 85) { "Green" } elseif ($performancePercentage -ge 70) { "Yellow" } else { "Red" }
    
    # Generate comprehensive performance summary
    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "              PERFORMANCE ANALYSIS SUMMARY" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    Write-Host "`n⚡ RESPONSE TIME PERFORMANCE:" -ForegroundColor Cyan
    Write-Host "  • Web Server Average: $([math]::Round($webAvgTime, 2)) ms" -ForegroundColor $(if ($webAvgTime -lt 200) { "Green" } else { "Yellow" })
    Write-Host "  • Application Service Average: $([math]::Round($appAvgTime, 2)) ms" -ForegroundColor $(if ($appAvgTime -lt 200) { "Green" } else { "Yellow" })
    Write-Host "  • Network Latency Average: $(if ($pingAvgTime) { "$([math]::Round($pingAvgTime, 2)) ms" } else { "N/A" })" -ForegroundColor $(if ($pingAvgTime -and $pingAvgTime -lt 50) { "Green" } else { "Yellow" })
    
    Write-Host "`n🔧 RELIABILITY METRICS:" -ForegroundColor Cyan
    Write-Host "  • Web Server Success Rate: $([math]::Round($performanceResults.WebServer.SuccessRate, 1))%" -ForegroundColor $(if ($performanceResults.WebServer.SuccessRate -gt 95) { "Green" } else { "Yellow" })
    Write-Host "  • Application Service Success Rate: $([math]::Round($performanceResults.AppService.SuccessRate, 1))%" -ForegroundColor $(if ($performanceResults.AppService.SuccessRate -gt 95) { "Green" } else { "Yellow" })
    Write-Host "  • Network Connectivity: $([math]::Round($performanceResults.NetworkLatency.SuccessRate, 1))%" -ForegroundColor $(if ($performanceResults.NetworkLatency.SuccessRate -gt 95) { "Green" } else { "Yellow" })
    
    Write-Host "`n📊 LOAD & STABILITY:" -ForegroundColor Cyan
    Write-Host "  • Concurrent Load Success: $([math]::Round($performanceResults.LoadTest.SuccessRate, 1))%" -ForegroundColor $(if ($performanceResults.LoadTest.SuccessRate -gt 90) { "Green" } else { "Yellow" })
    Write-Host "  • Service Stability: $([math]::Round($stabilitySuccessRate, 1))%" -ForegroundColor $(if ($stabilitySuccessRate -gt 95) { "Green" } else { "Yellow" })
    
    Write-Host "`n🎯 OVERALL PERFORMANCE SCORE: $performancePercentage% - $performanceLevel" -ForegroundColor $scoreColor
    Write-Host "   Score Breakdown:" -ForegroundColor White
    Write-Host "   • Response Time: $responseTimeScore/30 points" -ForegroundColor White
    Write-Host "   • Reliability: $reliabilityScore/25 points" -ForegroundColor White
    Write-Host "   • Network Quality: $networkScore/20 points" -ForegroundColor White
    Write-Host "   • Load Handling: $loadScore/15 points" -ForegroundColor White
    Write-Host "   • Stability: $stabilityScore/10 points" -ForegroundColor White
    
    Write-Host "`n📋 PERFORMANCE ASSESSMENT:" -ForegroundColor Cyan
    if ($performancePercentage -ge 85) {
        Write-Host "  ✅ Excellent performance across all metrics" -ForegroundColor Green
        Write-Host "  ✅ Ready for production workloads" -ForegroundColor Green
        Write-Host "  ✅ Minimal optimization required" -ForegroundColor Green
    } elseif ($performancePercentage -ge 70) {
        Write-Host "  ✅ Good overall performance" -ForegroundColor Yellow
        Write-Host "  ⚠️  Some areas for improvement identified" -ForegroundColor Yellow
        Write-Host "  ✅ Suitable for most workloads" -ForegroundColor Yellow
    } else {
        Write-Host "  ⚠️  Performance issues detected" -ForegroundColor Red
        Write-Host "  ❌ Optimization required before production" -ForegroundColor Red
        Write-Host "  🔧 Service tuning recommended" -ForegroundColor Red
    }
    
    # Create detailed performance report
    $reportContent = @"
# MCP Server Performance Analysis Report

## Analysis Date
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Target Server
- **IP Address**: $mcpServerIP
- **Performance Score**: $performancePercentage% ($performanceLevel)

## Response Time Analysis

### Web Server (Port 80)
- **Average Response Time**: $([math]::Round($webAvgTime, 2)) ms
- **Min/Max Response Time**: $([math]::Round($webMinTime, 2)) ms / $([math]::Round($webMaxTime, 2)) ms
- **Success Rate**: $([math]::Round($performanceResults.WebServer.SuccessRate, 1))%
- **Assessment**: $(if ($webAvgTime -lt 200) { "Excellent" } elseif ($webAvgTime -lt 500) { "Good" } else { "Needs Improvement" })

### Application Service (Port 3001)
- **Average Response Time**: $([math]::Round($appAvgTime, 2)) ms
- **Min/Max Response Time**: $([math]::Round($appMinTime, 2)) ms / $([math]::Round($appMaxTime, 2)) ms
- **Success Rate**: $([math]::Round($performanceResults.AppService.SuccessRate, 1))%
- **Assessment**: $(if ($appAvgTime -lt 200) { "Excellent" } elseif ($appAvgTime -lt 500) { "Good" } else { "Needs Improvement" })

## Network Performance
- **Average Latency**: $(if ($pingAvgTime) { "$([math]::Round($pingAvgTime, 2)) ms" } else { "N/A" })
- **Min/Max Latency**: $(if ($pingMinTime) { "$([math]::Round($pingMinTime, 2)) ms / $([math]::Round($pingMaxTime, 2)) ms" } else { "N/A" })
- **Connectivity Success Rate**: $([math]::Round($performanceResults.NetworkLatency.SuccessRate, 1))%
- **Assessment**: $(if ($pingAvgTime -and $pingAvgTime -lt 50) { "Excellent" } elseif ($pingAvgTime -and $pingAvgTime -lt 100) { "Good" } else { "Fair" })

## Load Testing Results
- **Concurrent Requests**: $($performanceResults.LoadTest.ConcurrentRequests)
- **Successful Requests**: $($performanceResults.LoadTest.SuccessfulRequests)
- **Success Rate**: $([math]::Round($performanceResults.LoadTest.SuccessRate, 1))%
- **Average Concurrent Response**: $(if ($performanceResults.LoadTest.AverageResponseTime -ne "N/A") { "$($performanceResults.LoadTest.AverageResponseTime) ms" } else { "N/A" })

## Stability Assessment
- **Stability Tests**: $($performanceResults.Stability.TestCount)
- **Test Interval**: $($performanceResults.Stability.TestInterval) seconds
- **Success Rate**: $([math]::Round($performanceResults.Stability.SuccessRate, 1))%
- **Assessment**: $(if ($stabilitySuccessRate -gt 95) { "Highly Stable" } elseif ($stabilitySuccessRate -gt 90) { "Stable" } else { "Stability Concerns" })

## Performance Score Breakdown
- **Response Time Score**: $responseTimeScore/30 points
- **Reliability Score**: $reliabilityScore/25 points
- **Network Quality Score**: $networkScore/20 points
- **Load Handling Score**: $loadScore/15 points
- **Stability Score**: $stabilityScore/10 points
- **Total Score**: $performanceScore/100 points ($performancePercentage%)

## Recommendations

### Immediate Actions
$(if ($performancePercentage -ge 85) {
"✅ Performance is excellent - maintain current configuration
✅ Implement monitoring to track performance trends
✅ Consider capacity planning for future growth"
} elseif ($performancePercentage -ge 70) {
"⚠️ Monitor response times during peak usage
⚠️ Consider caching strategies for improved performance
✅ Performance is acceptable for current workloads"
} else {
"❌ Immediate performance optimization required
❌ Review server resource allocation
❌ Analyze service configurations for bottlenecks"
})

### Long-term Optimizations
1. **Performance Monitoring**
   - Implement real-time performance dashboards
   - Set up alerting for performance degradation
   - Track performance trends over time

2. **Capacity Planning**
   - Monitor resource usage patterns
   - Plan for traffic growth
   - Optimize resource allocation

3. **Service Optimization**
   - Review and optimize service configurations
   - Implement caching where appropriate
   - Consider load balancing for high availability

## Next Steps
1. Set up continuous performance monitoring
2. Establish performance baselines and thresholds
3. Implement automated alerting for performance issues
4. Plan regular performance reviews and optimizations

---
*Generated by MCP Server Performance Analysis Tool*
*Status: Performance Analysis Complete*
"@
    
    $reportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "reports\mcp_performance_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    # Ensure reports directory exists
    $reportsDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host "`n📝 Performance analysis report saved: $reportPath" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Performance analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "           PERFORMANCE ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue"