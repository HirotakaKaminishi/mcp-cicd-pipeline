# Comprehensive MCP Server Optimization Verification Script

$mcpServerIP = "192.168.111.200"

Write-Host "======================================" -ForegroundColor Green
Write-Host "  MCP SERVER OPTIMIZATION VERIFICATION" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target Server: $mcpServerIP" -ForegroundColor Cyan

try {
    Write-Host "`n🔍 Phase 1: Basic Connectivity Verification..." -ForegroundColor Yellow
    
    # Test basic connectivity first
    Write-Host "Testing basic network connectivity..." -ForegroundColor Cyan
    
    $connectivityResults = @{}
    
    # Test ping connectivity
    try {
        $pingResult = Test-Connection -ComputerName $mcpServerIP -Count 3 -ErrorAction Stop
        $avgPing = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
        $connectivityResults.Ping = @{
            Status = "Success"
            AverageTime = [math]::Round($avgPing, 2)
        }
        Write-Host "  ✅ Ping successful - Average: $([math]::Round($avgPing, 2))ms" -ForegroundColor Green
    } catch {
        $connectivityResults.Ping = @{
            Status = "Failed"
            Error = $_.Exception.Message
        }
        Write-Host "  ❌ Ping failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test key ports
    $testPorts = @(80, 443, 8080, 22, 2222, 3001)
    $connectivityResults.Ports = @{}
    
    Write-Host "`nTesting port accessibility..." -ForegroundColor Cyan
    foreach ($port in $testPorts) {
        try {
            $portTest = Test-NetConnection -ComputerName $mcpServerIP -Port $port -WarningAction SilentlyContinue
            $connectivityResults.Ports[$port] = $portTest.TcpTestSucceeded
            $status = if ($portTest.TcpTestSucceeded) { "Open" } else { "Closed" }
            $color = if ($portTest.TcpTestSucceeded) { "Green" } else { "Gray" }
            Write-Host "  Port $port`: $status" -ForegroundColor $color
        } catch {
            $connectivityResults.Ports[$port] = $false
            Write-Host "  Port $port`: Error testing" -ForegroundColor Red
        }
    }
    
    Write-Host "`n🔍 Phase 2: HTTP/HTTPS Service Verification..." -ForegroundColor Yellow
    
    $httpResults = @{}
    
    # Test HTTP service
    Write-Host "Testing HTTP service..." -ForegroundColor Cyan
    try {
        $httpResponse = Invoke-WebRequest -Uri "http://$mcpServerIP" -Method GET -TimeoutSec 10 -ErrorAction Stop
        $httpResults.HTTP = @{
            Status = "Success"
            StatusCode = $httpResponse.StatusCode
            Server = $httpResponse.Headers.Server
            ContentLength = $httpResponse.RawContentLength
        }
        Write-Host "  ✅ HTTP service responding - Status: $($httpResponse.StatusCode)" -ForegroundColor Green
        if ($httpResponse.Headers.Server) {
            Write-Host "    Server: $($httpResponse.Headers.Server)" -ForegroundColor White
        }
    } catch {
        $httpResults.HTTP = @{
            Status = "Failed"
            Error = $_.Exception.Message
        }
        Write-Host "  ❌ HTTP service error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test HTTPS service
    Write-Host "`nTesting HTTPS service..." -ForegroundColor Cyan
    try {
        $httpsResponse = Invoke-WebRequest -Uri "https://$mcpServerIP" -Method GET -TimeoutSec 10 -ErrorAction Stop
        $httpResults.HTTPS = @{
            Status = "Success"
            StatusCode = $httpsResponse.StatusCode
            Server = $httpsResponse.Headers.Server
        }
        Write-Host "  ✅ HTTPS service responding - Status: $($httpsResponse.StatusCode)" -ForegroundColor Green
    } catch {
        $httpResults.HTTPS = @{
            Status = "Failed"
            Error = $_.Exception.Message
        }
        Write-Host "  ⚠️  HTTPS service not available: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "`n🔍 Phase 3: Security Headers Verification..." -ForegroundColor Yellow
    
    $securityResults = @{}
    
    # Test security headers
    Write-Host "Testing security headers..." -ForegroundColor Cyan
    try {
        $testUrl = if ($httpResults.HTTPS.Status -eq "Success") { "https://$mcpServerIP" } else { "http://$mcpServerIP" }
        $securityResponse = Invoke-WebRequest -Uri $testUrl -Method GET -TimeoutSec 10 -ErrorAction Stop
        
        $securityHeaders = @(
            "Strict-Transport-Security",
            "Content-Security-Policy", 
            "X-Frame-Options",
            "X-Content-Type-Options",
            "X-XSS-Protection",
            "Referrer-Policy"
        )
        
        $securityResults.Headers = @{}
        $presentHeaders = 0
        
        foreach ($header in $securityHeaders) {
            if ($securityResponse.Headers.$header) {
                $securityResults.Headers[$header] = @{
                    Present = $true
                    Value = $securityResponse.Headers.$header
                }
                Write-Host "  ✅ $header`: Present" -ForegroundColor Green
                $presentHeaders++
            } else {
                $securityResults.Headers[$header] = @{
                    Present = $false
                }
                Write-Host "  ❌ $header`: Missing" -ForegroundColor Red
            }
        }
        
        $securityResults.Score = [math]::Round(($presentHeaders / $securityHeaders.Count) * 100, 1)
        Write-Host "`n  📊 Security Headers Score: $($securityResults.Score)% ($presentHeaders/$($securityHeaders.Count))" -ForegroundColor $(if ($securityResults.Score -ge 80) { "Green" } else { "Yellow" })
        
    } catch {
        $securityResults.Error = $_.Exception.Message
        Write-Host "  ❌ Security headers test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n🔍 Phase 4: MCP Service Functionality Test..." -ForegroundColor Yellow
    
    $mcpResults = @{}
    
    # Test MCP service endpoints
    Write-Host "Testing MCP service functionality..." -ForegroundColor Cyan
    
    $mcpEndpoints = @{
        "/" = "Root endpoint"
        "/health" = "Health check"
        "/api/health" = "API health check"
        "/api/info" = "API information"
        "/api/status" = "API status"
    }
    
    $mcpResults.Endpoints = @{}
    $workingEndpoints = 0
    
    foreach ($endpoint in $mcpEndpoints.Keys) {
        try {
            $mcpUrl = "http://$mcpServerIP`:8080$endpoint"
            $mcpResponse = Invoke-WebRequest -Uri $mcpUrl -Method GET -TimeoutSec 10 -ErrorAction Stop
            $mcpResults.Endpoints[$endpoint] = @{
                Status = "Success"
                StatusCode = $mcpResponse.StatusCode
                ContentType = $mcpResponse.Headers.'Content-Type'
            }
            Write-Host "  ✅ $endpoint ($($mcpEndpoints[$endpoint])): $($mcpResponse.StatusCode)" -ForegroundColor Green
            $workingEndpoints++
        } catch {
            $mcpResults.Endpoints[$endpoint] = @{
                Status = "Failed"
                Error = $_.Exception.Message
            }
            if ($_.Exception.Message -like "*501*") {
                Write-Host "  ⚠️  $endpoint`: 501 Not Implemented" -ForegroundColor Yellow
            } else {
                Write-Host "  ❌ $endpoint`: Failed - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    $mcpResults.Score = [math]::Round(($workingEndpoints / $mcpEndpoints.Count) * 100, 1)
    Write-Host "`n  📊 MCP Service Score: $($mcpResults.Score)% ($workingEndpoints/$($mcpEndpoints.Count) endpoints working)" -ForegroundColor $(if ($mcpResults.Score -ge 80) { "Green" } else { "Yellow" })
    
    Write-Host "`n🔍 Phase 5: HTTP Methods Testing..." -ForegroundColor Yellow
    
    $methodResults = @{}
    
    # Test different HTTP methods
    Write-Host "Testing HTTP methods on MCP service..." -ForegroundColor Cyan
    
    $httpMethods = @("GET", "POST", "PUT", "DELETE", "OPTIONS")
    $methodResults.Methods = @{}
    $workingMethods = 0
    
    foreach ($method in $httpMethods) {
        try {
            $mcpUrl = "http://$mcpServerIP`:8080/"
            
            if ($method -eq "POST" -or $method -eq "PUT") {
                $methodResponse = Invoke-WebRequest -Uri $mcpUrl -Method $method -Body '{"test": "data"}' -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
            } else {
                $methodResponse = Invoke-WebRequest -Uri $mcpUrl -Method $method -TimeoutSec 10 -ErrorAction Stop
            }
            
            $methodResults.Methods[$method] = @{
                Status = "Success"
                StatusCode = $methodResponse.StatusCode
            }
            Write-Host "  ✅ $method method: $($methodResponse.StatusCode)" -ForegroundColor Green
            $workingMethods++
            
        } catch {
            $methodResults.Methods[$method] = @{
                Status = "Failed"
                Error = $_.Exception.Message
            }
            
            if ($_.Exception.Message -like "*501*") {
                Write-Host "  ⚠️  $method method: 501 Not Implemented" -ForegroundColor Yellow
            } elseif ($_.Exception.Message -like "*405*") {
                Write-Host "  ⚠️  $method method: 405 Method Not Allowed" -ForegroundColor Yellow
            } else {
                Write-Host "  ❌ $method method: Failed" -ForegroundColor Red
            }
        }
    }
    
    $methodResults.Score = [math]::Round(($workingMethods / $httpMethods.Count) * 100, 1)
    Write-Host "`n  📊 HTTP Methods Score: $($methodResults.Score)% ($workingMethods/$($httpMethods.Count) methods working)" -ForegroundColor $(if ($methodResults.Score -ge 80) { "Green" } else { "Yellow" })
    
    Write-Host "`n🔍 Phase 6: Performance Verification..." -ForegroundColor Yellow
    
    $performanceResults = @{}
    
    # Test response times
    Write-Host "Testing response times..." -ForegroundColor Cyan
    
    $testUrls = @(
        "http://$mcpServerIP",
        "http://$mcpServerIP`:8080",
        "http://$mcpServerIP`:3001"
    )
    
    $performanceResults.ResponseTimes = @{}
    
    foreach ($url in $testUrls) {
        try {
            $times = @()
            for ($i = 0; $i -lt 5; $i++) {
                $startTime = Get-Date
                $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 10 -ErrorAction Stop
                $endTime = Get-Date
                $responseTime = ($endTime - $startTime).TotalMilliseconds
                $times += $responseTime
            }
            
            $avgTime = [math]::Round(($times | Measure-Object -Average).Average, 2)
            $minTime = [math]::Round(($times | Measure-Object -Minimum).Minimum, 2)
            $maxTime = [math]::Round(($times | Measure-Object -Maximum).Maximum, 2)
            
            $performanceResults.ResponseTimes[$url] = @{
                Average = $avgTime
                Min = $minTime
                Max = $maxTime
                Status = "Success"
            }
            
            Write-Host "  ✅ $url`: Avg ${avgTime}ms (Min: ${minTime}ms, Max: ${maxTime}ms)" -ForegroundColor Green
            
        } catch {
            $performanceResults.ResponseTimes[$url] = @{
                Status = "Failed"
                Error = $_.Exception.Message
            }
            Write-Host "  ❌ $url`: Failed - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n🔍 Phase 7: SSH Security Verification..." -ForegroundColor Yellow
    
    $sshResults = @{}
    
    # Test SSH connectivity
    Write-Host "Testing SSH connectivity..." -ForegroundColor Cyan
    
    # Test default SSH port (should be closed if hardened)
    $sshPort22 = Test-NetConnection -ComputerName $mcpServerIP -Port 22 -WarningAction SilentlyContinue
    $sshPort2222 = Test-NetConnection -ComputerName $mcpServerIP -Port 2222 -WarningAction SilentlyContinue
    
    $sshResults.DefaultPort = $sshPort22.TcpTestSucceeded
    $sshResults.CustomPort = $sshPort2222.TcpTestSucceeded
    
    if (-not $sshPort22.TcpTestSucceeded) {
        Write-Host "  ✅ SSH default port (22): Closed (Security hardened)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  SSH default port (22): Open (Consider hardening)" -ForegroundColor Yellow
    }
    
    if ($sshPort2222.TcpTestSucceeded) {
        Write-Host "  ✅ SSH custom port (2222): Open" -ForegroundColor Green
    } else {
        Write-Host "  ❌ SSH custom port (2222): Closed" -ForegroundColor Red
    }
    
    Write-Host "`n🔍 Phase 8: Overall System Assessment..." -ForegroundColor Yellow
    
    # Calculate overall scores
    $overallResults = @{}
    
    # Network connectivity score (20 points)
    $networkScore = 0
    if ($connectivityResults.Ping.Status -eq "Success") {
        $networkScore += 10
        if ($connectivityResults.Ping.AverageTime -lt 50) { $networkScore += 5 }
        if ($connectivityResults.Ping.AverageTime -lt 20) { $networkScore += 5 }
    }
    
    # Service availability score (25 points) 
    $serviceScore = 0
    $openPorts = ($connectivityResults.Ports.Values | Where-Object { $_ -eq $true }).Count
    $serviceScore = [math]::Min(25, $openPorts * 4)
    
    # Security score (25 points)
    $securityScore = 0
    if ($securityResults.Score) {
        $securityScore = [math]::Round($securityResults.Score * 0.25, 0)
    }
    
    # MCP functionality score (20 points)
    $mcpScore = 0
    if ($mcpResults.Score) {
        $mcpScore = [math]::Round($mcpResults.Score * 0.20, 0)
    }
    
    # Performance score (10 points)
    $performanceScore = 0
    $workingServices = ($performanceResults.ResponseTimes.Values | Where-Object { $_.Status -eq "Success" }).Count
    $performanceScore = [math]::Min(10, $workingServices * 3)
    
    $totalScore = $networkScore + $serviceScore + $securityScore + $mcpScore + $performanceScore
    $overallPercentage = [math]::Round(($totalScore / 100) * 100, 1)
    
    $overallResults.Scores = @{
        Network = $networkScore
        Service = $serviceScore  
        Security = $securityScore
        MCP = $mcpScore
        Performance = $performanceScore
        Total = $totalScore
        Percentage = $overallPercentage
    }
    
    # Generate comprehensive summary
    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "           COMPREHENSIVE VERIFICATION SUMMARY" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    Write-Host "`n🌐 NETWORK CONNECTIVITY:" -ForegroundColor Cyan
    Write-Host "  • Ping Response: $(if ($connectivityResults.Ping.Status -eq "Success") { "✅ $($connectivityResults.Ping.AverageTime)ms" } else { "❌ Failed" })" -ForegroundColor $(if ($connectivityResults.Ping.Status -eq "Success") { "Green" } else { "Red" })
    Write-Host "  • Open Ports: $($openPorts) of $($testPorts.Count) tested" -ForegroundColor $(if ($openPorts -ge 4) { "Green" } else { "Yellow" })
    Write-Host "  • Score: $networkScore/20 points" -ForegroundColor White
    
    Write-Host "`n🔧 SERVICE AVAILABILITY:" -ForegroundColor Cyan
    Write-Host "  • HTTP Service: $(if ($httpResults.HTTP.Status -eq "Success") { "✅ Working" } else { "❌ Failed" })" -ForegroundColor $(if ($httpResults.HTTP.Status -eq "Success") { "Green" } else { "Red" })
    Write-Host "  • HTTPS Service: $(if ($httpResults.HTTPS.Status -eq "Success") { "✅ Working" } else { "⚠️ Not configured" })" -ForegroundColor $(if ($httpResults.HTTPS.Status -eq "Success") { "Green" } else { "Yellow" })
    Write-Host "  • Score: $serviceScore/25 points" -ForegroundColor White
    
    Write-Host "`n🛡️  SECURITY CONFIGURATION:" -ForegroundColor Cyan
    Write-Host "  • Security Headers: $(if ($securityResults.Score) { "$($securityResults.Score)%" } else { "Not tested" })" -ForegroundColor $(if ($securityResults.Score -and $securityResults.Score -ge 80) { "Green" } elseif ($securityResults.Score) { "Yellow" } else { "Red" })
    Write-Host "  • SSH Hardening: $(if (-not $sshResults.DefaultPort -and $sshResults.CustomPort) { "✅ Properly configured" } else { "⚠️ Needs improvement" })" -ForegroundColor $(if (-not $sshResults.DefaultPort -and $sshResults.CustomPort) { "Green" } else { "Yellow" })
    Write-Host "  • Score: $securityScore/25 points" -ForegroundColor White
    
    Write-Host "`n🤖 MCP SERVICE FUNCTIONALITY:" -ForegroundColor Cyan
    Write-Host "  • Endpoint Availability: $(if ($mcpResults.Score) { "$($mcpResults.Score)%" } else { "Not tested" })" -ForegroundColor $(if ($mcpResults.Score -and $mcpResults.Score -ge 80) { "Green" } elseif ($mcpResults.Score) { "Yellow" } else { "Red" })
    Write-Host "  • HTTP Methods: $(if ($methodResults.Score) { "$($methodResults.Score)%" } else { "Not tested" })" -ForegroundColor $(if ($methodResults.Score -and $methodResults.Score -ge 80) { "Green" } elseif ($methodResults.Score) { "Yellow" } else { "Red" })
    Write-Host "  • Score: $mcpScore/20 points" -ForegroundColor White
    
    Write-Host "`n⚡ PERFORMANCE METRICS:" -ForegroundColor Cyan
    $avgResponseTime = if ($performanceResults.ResponseTimes.Values | Where-Object { $_.Status -eq "Success" }) {
        [math]::Round((($performanceResults.ResponseTimes.Values | Where-Object { $_.Status -eq "Success" } | ForEach-Object { $_.Average }) | Measure-Object -Average).Average, 2)
    } else { "N/A" }
    Write-Host "  • Average Response Time: $avgResponseTime ms" -ForegroundColor $(if ($avgResponseTime -ne "N/A" -and $avgResponseTime -lt 200) { "Green" } else { "Yellow" })
    Write-Host "  • Working Services: $workingServices of $($testUrls.Count)" -ForegroundColor $(if ($workingServices -eq $testUrls.Count) { "Green" } else { "Yellow" })
    Write-Host "  • Score: $performanceScore/10 points" -ForegroundColor White
    
    Write-Host "`n🎯 OVERALL SYSTEM HEALTH: $overallPercentage% - $(if ($overallPercentage -ge 85) { "EXCELLENT" } elseif ($overallPercentage -ge 70) { "GOOD" } elseif ($overallPercentage -ge 55) { "FAIR" } else { "POOR" })" -ForegroundColor $(if ($overallPercentage -ge 85) { "Green" } elseif ($overallPercentage -ge 70) { "Yellow" } else { "Red" })
    Write-Host "   Total Score: $totalScore/100 points" -ForegroundColor White
    
    Write-Host "`n📋 VERIFICATION FINDINGS:" -ForegroundColor Cyan
    
    # Key findings and recommendations
    $findings = @()
    $recommendations = @()
    
    if ($connectivityResults.Ping.Status -eq "Success") {
        $findings += "OK - Server is reachable and responding"
    } else {
        $findings += "Error - Server connectivity issues detected"
        $recommendations += "• Check network connectivity and firewall settings"
    }
    
    if ($httpResults.HTTP.Status -eq "Success") {
        $findings += "OK - HTTP service is operational"
    } else {
        $findings += "Error - HTTP service issues detected"
        $recommendations += "• Investigate HTTP service configuration"
    }
    
    if ($httpResults.HTTPS.Status -eq "Success") {
        $findings += "OK - HTTPS service is operational"
    } else {
        $findings += "Warning - HTTPS service not configured"
        $recommendations += "• Implement SSL/TLS certificates"
    }
    
    if ($securityResults.Score -and $securityResults.Score -ge 80) {
        $findings += "OK - Security headers properly configured"
    } else {
        $findings += "Warning - Security headers need improvement"
        $recommendations += "• Implement comprehensive security headers"
    }
    
    if ($mcpResults.Score -and $mcpResults.Score -ge 80) {
        $findings += "OK - MCP service is highly functional"
    } else {
        $findings += "Warning - MCP service has limited functionality"
        $recommendations += "• Fix MCP service implementation issues"
    }
    
    foreach ($finding in $findings) {
        $findingColor = "White"
        if ($finding.Contains("OK") -or $finding.Contains("Success") -or $finding.Contains("operational")) {
            $findingColor = "Green"
        } elseif ($finding.Contains("Warning") -or $finding.Contains("needs") -or $finding.Contains("not configured")) {
            $findingColor = "Yellow"
        } elseif ($finding.Contains("Error") -or $finding.Contains("Failed") -or $finding.Contains("issues")) {
            $findingColor = "Red"
        }
        Write-Host "  $finding" -ForegroundColor $findingColor
    }
    
    if ($recommendations.Count -gt 0) {
        Write-Host "`n🔧 RECOMMENDATIONS:" -ForegroundColor Cyan
        foreach ($recommendation in $recommendations) {
            Write-Host "  $recommendation" -ForegroundColor White
        }
    }
    
    # Create verification report
    $reportContent = @"
# MCP Server Optimization Verification Report

## Verification Date
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Target Server
- **IP Address**: $mcpServerIP
- **Overall Health Score**: $overallPercentage% ($(if ($overallPercentage -ge 85) { "EXCELLENT" } elseif ($overallPercentage -ge 70) { "GOOD" } elseif ($overallPercentage -ge 55) { "FAIR" } else { "POOR" }))

## Verification Results Summary

### Network Connectivity
- **Ping Status**: $(if ($connectivityResults.Ping.Status -eq "Success") { "✅ Success ($($connectivityResults.Ping.AverageTime)ms average)" } else { "❌ Failed" })
- **Port Accessibility**: $openPorts of $($testPorts.Count) ports open
- **Score**: $networkScore/20 points

### Service Availability  
- **HTTP Service**: $(if ($httpResults.HTTP.Status -eq "Success") { "✅ Operational (Status: $($httpResults.HTTP.StatusCode))" } else { "❌ Failed" })
- **HTTPS Service**: $(if ($httpResults.HTTPS.Status -eq "Success") { "✅ Operational (Status: $($httpResults.HTTPS.StatusCode))" } else { "⚠️ Not configured" })
- **Server Information**: $(if ($httpResults.HTTP.Server) { $httpResults.HTTP.Server } else { "Not available" })
- **Score**: $serviceScore/25 points

### Security Configuration
- **Security Headers Score**: $(if ($securityResults.Score) { "$($securityResults.Score)%" } else { "Not tested" })
$(if ($securityResults.Headers) {
    foreach ($header in $securityResults.Headers.Keys) {
        $status = if ($securityResults.Headers[$header].Present) { "✅ Present" } else { "❌ Missing" }
        "- **$header**: $status"
    }
})
- **SSH Configuration**: $(if (-not $sshResults.DefaultPort -and $sshResults.CustomPort) { "✅ Hardened (Default port closed, custom port active)" } else { "⚠️ Needs hardening" })
- **Score**: $securityScore/25 points

### MCP Service Functionality
- **Service Availability**: $(if ($mcpResults.Score) { "$($mcpResults.Score)%" } else { "Not tested" })
$(if ($mcpResults.Endpoints) {
    foreach ($endpoint in $mcpResults.Endpoints.Keys) {
        $status = if ($mcpResults.Endpoints[$endpoint].Status -eq "Success") { 
            "✅ Working (Status: $($mcpResults.Endpoints[$endpoint].StatusCode))" 
        } else { 
            "❌ Failed" 
        }
        "- **$endpoint**: $status"
    }
})

- **HTTP Methods Support**: $(if ($methodResults.Score) { "$($methodResults.Score)%" } else { "Not tested" })
$(if ($methodResults.Methods) {
    foreach ($method in $methodResults.Methods.Keys) {
        $status = if ($methodResults.Methods[$method].Status -eq "Success") { 
            "✅ Working (Status: $($methodResults.Methods[$method].StatusCode))" 
        } else { 
            "❌ Failed" 
        }
        "- **$method**: $status"
    }
})
- **Score**: $mcpScore/20 points

### Performance Metrics
$(if ($performanceResults.ResponseTimes) {
    foreach ($url in $performanceResults.ResponseTimes.Keys) {
        if ($performanceResults.ResponseTimes[$url].Status -eq "Success") {
            $avg = $performanceResults.ResponseTimes[$url].Average
            "- **$url**: Average $($avg)ms (Min: $($performanceResults.ResponseTimes[$url].Min)ms, Max: $($performanceResults.ResponseTimes[$url].Max)ms)"
        } else {
            "- **$url**: Failed to test"
        }
    }
})
- **Score**: $performanceScore/10 points

## Detailed Findings

### Positive Findings
- Positive findings will be listed based on verification results

### Areas for Improvement  
- Areas needing improvement will be listed based on verification results

## Recommendations

### Immediate Actions Required
$(foreach ($recommendation in $recommendations) {
    "- $recommendation"
})

### Optimization Status Assessment

Based on the verification results, the optimization implementation status is:

$(if ($overallPercentage -ge 85) {
    "🎉 **EXCELLENT** - Optimization goals achieved
- System is performing at optimal levels
- All major security measures implemented
- Services are highly available and functional
- Ready for production workloads"
} elseif ($overallPercentage -ge 70) {
    "✅ **GOOD** - Most optimizations successful
- System performance is significantly improved
- Core security measures implemented
- Some minor issues remain to be addressed
- Suitable for production with monitoring"
} elseif ($overallPercentage -ge 55) {
    "⚠️ **FAIR** - Partial optimization success
- Some improvements achieved
- Critical issues still need attention
- Additional optimization work required
- Not ready for production deployment"
} else {
    "❌ **POOR** - Optimization needs significant work
- Major issues detected
- Core services may not be functioning properly
- Immediate attention and troubleshooting required
- Not suitable for production use"
})

## Next Steps

1. **Address Critical Issues**: Focus on any failing services or security gaps
2. **Monitor Performance**: Establish baseline metrics and monitoring
3. **Security Hardening**: Complete any remaining security implementations
4. **Performance Tuning**: Fine-tune based on actual usage patterns
5. **Documentation**: Update system documentation with current configuration

## Verification Conclusion

The MCP server verification shows a system health score of **$overallPercentage%**, indicating $(if ($overallPercentage -ge 85) { "excellent" } elseif ($overallPercentage -ge 70) { "good" } elseif ($overallPercentage -ge 55) { "fair" } else { "poor" }) optimization results. $(if ($overallPercentage -ge 70) { "The server is ready for production use with proper monitoring." } else { "Additional optimization work is recommended before production deployment." })

---
*Generated by MCP Server Comprehensive Verification Tool*
*Verification Status: Complete*
*Overall Assessment: $(if ($overallPercentage -ge 85) { "EXCELLENT" } elseif ($overallPercentage -ge 70) { "GOOD" } elseif ($overallPercentage -ge 55) { "FAIR" } else { "POOR" })*
"@
    
    $reportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "reports\comprehensive_verification_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    # Ensure reports directory exists
    $reportsDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host "`n📝 Comprehensive verification report saved: $reportPath" -ForegroundColor Cyan
    
    # Return results for next phase
    return @{
        OverallScore = $overallPercentage
        NetworkScore = $networkScore
        ServiceScore = $serviceScore
        SecurityScore = $securityScore
        MCPScore = $mcpScore
        PerformanceScore = $performanceScore
        ConnectivityResults = $connectivityResults
        HttpResults = $httpResults
        SecurityResults = $securityResults
        MCPResults = $mcpResults
        MethodResults = $methodResults
        PerformanceResults = $performanceResults
        SSHResults = $sshResults
    }
    
} catch {
    Write-Host "❌ Comprehensive verification failed: $($_.Exception.Message)" -ForegroundColor Red
    return $null
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "         COMPREHENSIVE VERIFICATION COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green