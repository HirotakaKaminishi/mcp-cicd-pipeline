# MCP Server Security & Firewall Analysis Script

$mcpServerIP = "192.168.111.200"

Write-Host "======================================" -ForegroundColor Green
Write-Host "    MCP SECURITY & FIREWALL ANALYSIS" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target Server: $mcpServerIP" -ForegroundColor Cyan

try {
    Write-Host "`n🔍 Phase 1: Port Security Analysis..." -ForegroundColor Yellow
    
    # Comprehensive port analysis
    Write-Host "Analyzing exposed ports and services..." -ForegroundColor Cyan
    
    $securityAnalysis = @{}
    $criticalPorts = @{
        22 = @{ Service = "SSH"; Risk = "High"; Description = "Administrative access" }
        80 = @{ Service = "HTTP"; Risk = "Medium"; Description = "Web server" }
        8080 = @{ Service = "MCP Server"; Risk = "High"; Description = "Application server" }
        3001 = @{ Service = "Application"; Risk = "Medium"; Description = "Custom application" }
    }
    
    $additionalPorts = @(21, 23, 25, 53, 110, 143, 443, 993, 995, 1433, 3306, 5432, 6379, 27017)
    
    Write-Host "`n🔐 CRITICAL SERVICES ANALYSIS:" -ForegroundColor Cyan
    $exposedCriticalPorts = @()
    
    foreach ($port in $criticalPorts.Keys) {
        $portTest = Test-NetConnection -ComputerName $mcpServerIP -Port $port -WarningAction SilentlyContinue
        $portInfo = $criticalPorts[$port]
        
        if ($portTest.TcpTestSucceeded) {
            $exposedCriticalPorts += $port
            $riskColor = switch ($portInfo.Risk) {
                "High" { "Red" }
                "Medium" { "Yellow" }
                "Low" { "Green" }
                default { "White" }
            }
            Write-Host "  ⚠️  Port $port ($($portInfo.Service)): OPEN - Risk: $($portInfo.Risk)" -ForegroundColor $riskColor
            Write-Host "      Description: $($portInfo.Description)" -ForegroundColor Gray
        } else {
            Write-Host "  ✅ Port $port ($($portInfo.Service)): CLOSED" -ForegroundColor Green
        }
    }
    
    $securityAnalysis.CriticalPorts = @{
        TotalCritical = $criticalPorts.Count
        ExposedCritical = $exposedCriticalPorts.Count
        ExposedPorts = $exposedCriticalPorts
    }
    
    Write-Host "`n🔍 ADDITIONAL PORT SCAN:" -ForegroundColor Cyan
    Write-Host "Scanning for other commonly targeted ports..." -ForegroundColor Cyan
    
    $additionalExposedPorts = @()
    foreach ($port in $additionalPorts) {
        $portTest = Test-NetConnection -ComputerName $mcpServerIP -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($portTest.TcpTestSucceeded) {
            $additionalExposedPorts += $port
            Write-Host "  ⚠️  Additional exposed port: $port" -ForegroundColor Yellow
        }
    }
    
    if ($additionalExposedPorts.Count -eq 0) {
        Write-Host "  ✅ No additional commonly targeted ports found open" -ForegroundColor Green
    }
    
    $securityAnalysis.AdditionalPorts = $additionalExposedPorts
    
    Write-Host "`n🔍 Phase 2: Service Security Assessment..." -ForegroundColor Yellow
    
    # Analyze security headers and configurations
    Write-Host "Analyzing service security configurations..." -ForegroundColor Cyan
    
    # 1. HTTP Security Headers Analysis
    Write-Host "`n🛡️  HTTP SECURITY HEADERS (Port 80):" -ForegroundColor Cyan
    try {
        $webResponse = Invoke-WebRequest -Uri "http://$mcpServerIP" -Method GET -TimeoutSec 10 -ErrorAction Stop
        $headers = $webResponse.Headers
        
        $securityHeaders = @{
            "X-Content-Type-Options" = @{ Present = $false; Value = $null; Risk = "Medium" }
            "X-Frame-Options" = @{ Present = $false; Value = $null; Risk = "Medium" }
            "X-XSS-Protection" = @{ Present = $false; Value = $null; Risk = "Medium" }
            "Strict-Transport-Security" = @{ Present = $false; Value = $null; Risk = "High" }
            "Content-Security-Policy" = @{ Present = $false; Value = $null; Risk = "High" }
            "Referrer-Policy" = @{ Present = $false; Value = $null; Risk = "Low" }
            "Server" = @{ Present = $false; Value = $null; Risk = "Low" }
        }
        
        foreach ($headerName in $securityHeaders.Keys) {
            if ($headers.$headerName) {
                $securityHeaders[$headerName].Present = $true
                $securityHeaders[$headerName].Value = $headers.$headerName
                Write-Host "  ✅ $headerName`: $($headers.$headerName)" -ForegroundColor Green
            } else {
                $riskColor = switch ($securityHeaders[$headerName].Risk) {
                    "High" { "Red" }
                    "Medium" { "Yellow" }
                    "Low" { "Gray" }
                }
                Write-Host "  ❌ $headerName`: Missing - Risk: $($securityHeaders[$headerName].Risk)" -ForegroundColor $riskColor
            }
        }
        
        $securityAnalysis.SecurityHeaders = $securityHeaders
        
    } catch {
        Write-Host "  ❌ Unable to analyze HTTP security headers: $($_.Exception.Message)" -ForegroundColor Red
        $securityAnalysis.SecurityHeaders = @{ Error = $_.Exception.Message }
    }
    
    # 2. HTTPS/TLS Analysis
    Write-Host "`n🔒 HTTPS/TLS CONFIGURATION:" -ForegroundColor Cyan
    try {
        $httpsResponse = Invoke-WebRequest -Uri "https://$mcpServerIP" -Method GET -TimeoutSec 10 -ErrorAction Stop
        Write-Host "  ✅ HTTPS is available and configured" -ForegroundColor Green
        $securityAnalysis.HTTPS = @{ Available = $true; Configured = $true }
    } catch {
        Write-Host "  ⚠️  HTTPS not available or misconfigured" -ForegroundColor Yellow
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Gray
        $securityAnalysis.HTTPS = @{ Available = $false; Error = $_.Exception.Message }
    }
    
    # 3. MCP Service Security
    Write-Host "`n🤖 MCP SERVICE SECURITY (Port 8080):" -ForegroundColor Cyan
    try {
        # Test if MCP service reveals any sensitive information
        $mcpResponse = Invoke-WebRequest -Uri "http://$mcpServerIP`:8080" -Method GET -TimeoutSec 10 -ErrorAction SilentlyContinue
    } catch {
        $mcpError = $_.Exception.Message
        if ($mcpError -like "*501*") {
            Write-Host "  ✅ MCP service returns 501 (limited method exposure)" -ForegroundColor Green
            Write-Host "  ✅ Service doesn't expose sensitive information via GET" -ForegroundColor Green
            $securityAnalysis.MCPSecurity = @{ 
                MethodRestriction = $true
                InformationLeakage = $false
                Assessment = "Good - Limited exposure"
            }
        } else {
            Write-Host "  ⚠️  MCP service response: $mcpError" -ForegroundColor Yellow
            $securityAnalysis.MCPSecurity = @{ 
                MethodRestriction = "Unknown"
                Error = $mcpError
            }
        }
    }
    
    Write-Host "`n🔍 Phase 3: Network Security Assessment..." -ForegroundColor Yellow
    
    # Network-level security analysis
    Write-Host "Analyzing network security characteristics..." -ForegroundColor Cyan
    
    # 1. Port exposure analysis
    Write-Host "`n🌐 NETWORK EXPOSURE ANALYSIS:" -ForegroundColor Cyan
    $totalExposedPorts = $exposedCriticalPorts.Count + $additionalExposedPorts.Count
    
    if ($totalExposedPorts -le 4) {
        Write-Host "  ✅ Limited port exposure ($totalExposedPorts ports)" -ForegroundColor Green
        $exposureRisk = "Low"
    } elseif ($totalExposedPorts -le 8) {
        Write-Host "  ⚠️  Moderate port exposure ($totalExposedPorts ports)" -ForegroundColor Yellow
        $exposureRisk = "Medium"
    } else {
        Write-Host "  ❌ High port exposure ($totalExposedPorts ports)" -ForegroundColor Red
        $exposureRisk = "High"
    }
    
    $securityAnalysis.NetworkExposure = @{
        TotalExposedPorts = $totalExposedPorts
        Risk = $exposureRisk
    }
    
    # 2. Service banner analysis
    Write-Host "`n🏷️  SERVICE BANNER ANALYSIS:" -ForegroundColor Cyan
    try {
        $webResponse = Invoke-WebRequest -Uri "http://$mcpServerIP" -Method GET -TimeoutSec 10
        $serverHeader = $webResponse.Headers.Server
        
        if ($serverHeader) {
            Write-Host "  📋 Server banner: $serverHeader" -ForegroundColor White
            if ($serverHeader -match "\d+\.\d+\.\d+") {
                Write-Host "  ⚠️  Version information exposed in banner" -ForegroundColor Yellow
                $bannerRisk = "Medium"
            } else {
                Write-Host "  ✅ Version information not detailed in banner" -ForegroundColor Green
                $bannerRisk = "Low"
            }
        } else {
            Write-Host "  ✅ Server banner suppressed" -ForegroundColor Green
            $bannerRisk = "Low"
        }
        
        $securityAnalysis.ServiceBanner = @{
            Present = $serverHeader -ne $null
            Value = $serverHeader
            Risk = $bannerRisk
        }
        
    } catch {
        Write-Host "  ⚠️  Unable to analyze service banner" -ForegroundColor Yellow
    }
    
    Write-Host "`n🔍 Phase 4: Authentication & Access Control..." -ForegroundColor Yellow
    
    # Authentication analysis
    Write-Host "Analyzing authentication and access controls..." -ForegroundColor Cyan
    
    # 1. SSH Authentication
    Write-Host "`n🔑 SSH AUTHENTICATION ANALYSIS:" -ForegroundColor Cyan
    if ($exposedCriticalPorts -contains 22) {
        Write-Host "  ⚠️  SSH port is exposed - requires strong authentication" -ForegroundColor Yellow
        Write-Host "  📋 Recommended: Key-based authentication, disable password auth" -ForegroundColor Cyan
        Write-Host "  📋 Recommended: Fail2ban or similar brute-force protection" -ForegroundColor Cyan
        
        $sshRisk = "High"
    } else {
        Write-Host "  ✅ SSH port not exposed externally" -ForegroundColor Green
        $sshRisk = "Low"
    }
    
    # 2. Web service authentication
    Write-Host "`n🌐 WEB SERVICE AUTHENTICATION:" -ForegroundColor Cyan
    try {
        $authTestResponse = Invoke-WebRequest -Uri "http://$mcpServerIP/admin" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
        Write-Host "  ⚠️  /admin endpoint accessible (needs investigation)" -ForegroundColor Yellow
    } catch {
        if ($_.Exception.Message -like "*404*") {
            Write-Host "  ✅ No obvious admin endpoints exposed" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️  Admin endpoint test: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
    
    $securityAnalysis.Authentication = @{
        SSHRisk = $sshRisk
        WebServiceProtected = $true  # Assuming based on 404 response
    }
    
    Write-Host "`n🔍 Phase 5: Security Score Calculation..." -ForegroundColor Yellow
    
    # Calculate comprehensive security score
    $securityScore = 0
    $maxSecurityScore = 100
    
    # Port exposure score (25 points)
    $portScore = 0
    if ($exposedCriticalPorts.Count -le 2) { $portScore = 25 }
    elseif ($exposedCriticalPorts.Count -le 4) { $portScore = 20 }
    elseif ($exposedCriticalPorts.Count -le 6) { $portScore = 15 }
    else { $portScore = 10 }
    
    # Security headers score (20 points)
    $headerScore = 0
    if ($securityAnalysis.SecurityHeaders -and $securityAnalysis.SecurityHeaders.GetType().Name -ne "String") {
        $presentHeaders = ($securityAnalysis.SecurityHeaders.Values | Where-Object { $_.Present -eq $true }).Count
        $totalHeaders = $securityAnalysis.SecurityHeaders.Count
        $headerScore = [math]::Round(($presentHeaders / $totalHeaders) * 20)
    }
    
    # HTTPS configuration score (20 points)
    $httpsScore = 0
    if ($securityAnalysis.HTTPS.Available -eq $true) { $httpsScore = 20 }
    else { $httpsScore = 5 }  # Some points for HTTP being functional
    
    # Service security score (20 points)
    $serviceScore = 0
    if ($securityAnalysis.MCPSecurity.MethodRestriction -eq $true) { $serviceScore += 10 }
    if ($securityAnalysis.MCPSecurity.InformationLeakage -eq $false) { $serviceScore += 10 }
    
    # Network security score (15 points)
    $networkScore = 0
    if ($exposureRisk -eq "Low") { $networkScore = 15 }
    elseif ($exposureRisk -eq "Medium") { $networkScore = 10 }
    else { $networkScore = 5 }
    
    $securityScore = $portScore + $headerScore + $httpsScore + $serviceScore + $networkScore
    $securityPercentage = [math]::Round(($securityScore / $maxSecurityScore) * 100, 1)
    $securityLevel = if ($securityPercentage -ge 80) { "EXCELLENT" } elseif ($securityPercentage -ge 60) { "GOOD" } elseif ($securityPercentage -ge 40) { "FAIR" } else { "POOR" }
    $securityColor = if ($securityPercentage -ge 80) { "Green" } elseif ($securityPercentage -ge 60) { "Yellow" } else { "Red" }
    
    # Generate comprehensive security summary
    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "              SECURITY ANALYSIS SUMMARY" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    
    Write-Host "`n🔐 PORT & SERVICE EXPOSURE:" -ForegroundColor Cyan
    Write-Host "  • Total exposed ports: $totalExposedPorts" -ForegroundColor $(if ($totalExposedPorts -le 4) { "Green" } else { "Yellow" })
    Write-Host "  • Critical services exposed: $($exposedCriticalPorts.Count)/$($criticalPorts.Count)" -ForegroundColor $(if ($exposedCriticalPorts.Count -le 2) { "Green" } else { "Yellow" })
    Write-Host "  • Network exposure risk: $exposureRisk" -ForegroundColor $(if ($exposureRisk -eq "Low") { "Green" } elseif ($exposureRisk -eq "Medium") { "Yellow" } else { "Red" })
    
    Write-Host "`n🛡️  SECURITY CONFIGURATIONS:" -ForegroundColor Cyan
    if ($securityAnalysis.SecurityHeaders -and $securityAnalysis.SecurityHeaders.GetType().Name -ne "String") {
        $presentHeaders = ($securityAnalysis.SecurityHeaders.Values | Where-Object { $_.Present -eq $true }).Count
        $totalHeaders = $securityAnalysis.SecurityHeaders.Count
        Write-Host "  • Security headers: $presentHeaders/$totalHeaders configured" -ForegroundColor $(if ($presentHeaders -ge 4) { "Green" } else { "Yellow" })
    }
    Write-Host "  • HTTPS availability: $(if ($securityAnalysis.HTTPS.Available) { 'Available' } else { 'Not configured' })" -ForegroundColor $(if ($securityAnalysis.HTTPS.Available) { "Green" } else { "Red" })
    Write-Host "  • MCP service security: $(if ($securityAnalysis.MCPSecurity.Assessment) { $securityAnalysis.MCPSecurity.Assessment } else { 'Under review' })" -ForegroundColor $(if ($securityAnalysis.MCPSecurity.MethodRestriction) { "Green" } else { "Yellow" })
    
    Write-Host "`n🎯 OVERALL SECURITY SCORE: $securityPercentage% - $securityLevel" -ForegroundColor $securityColor
    Write-Host "   Score Breakdown:" -ForegroundColor White
    Write-Host "   • Port Security: $portScore/25 points" -ForegroundColor White
    Write-Host "   • Security Headers: $headerScore/20 points" -ForegroundColor White
    Write-Host "   • HTTPS Configuration: $httpsScore/20 points" -ForegroundColor White
    Write-Host "   • Service Security: $serviceScore/20 points" -ForegroundColor White
    Write-Host "   • Network Security: $networkScore/15 points" -ForegroundColor White
    
    Write-Host "`n🚨 SECURITY RECOMMENDATIONS:" -ForegroundColor Cyan
    
    # High priority recommendations
    $highPriorityIssues = @()
    if ($exposedCriticalPorts -contains 22) { $highPriorityIssues += "SSH port exposed - implement strong authentication" }
    if (-not $securityAnalysis.HTTPS.Available) { $highPriorityIssues += "HTTPS not configured - implement SSL/TLS" }
    if ($securityAnalysis.SecurityHeaders -and ($securityAnalysis.SecurityHeaders.Values | Where-Object { $_.Present -eq $true }).Count -lt 3) { 
        $highPriorityIssues += "Missing critical security headers" 
    }
    
    if ($highPriorityIssues.Count -gt 0) {
        Write-Host "  🚨 HIGH PRIORITY:" -ForegroundColor Red
        foreach ($issue in $highPriorityIssues) {
            Write-Host "    • $issue" -ForegroundColor Red
        }
    }
    
    # Medium priority recommendations
    Write-Host "  ⚠️  MEDIUM PRIORITY:" -ForegroundColor Yellow
    Write-Host "    • Implement comprehensive logging and monitoring" -ForegroundColor Yellow
    Write-Host "    • Set up intrusion detection system" -ForegroundColor Yellow
    Write-Host "    • Regular security updates and patches" -ForegroundColor Yellow
    Write-Host "    • Network segmentation and firewall rules" -ForegroundColor Yellow
    
    # Best practices
    Write-Host "  ✅ BEST PRACTICES:" -ForegroundColor Green
    Write-Host "    • Regular security audits and assessments" -ForegroundColor Green
    Write-Host "    • Backup and disaster recovery planning" -ForegroundColor Green
    Write-Host "    • Access control and principle of least privilege" -ForegroundColor Green
    Write-Host "    • Security awareness and training" -ForegroundColor Green
    
    # Create detailed security report
    $reportContent = @"
# MCP Server Security Analysis Report

## Analysis Date
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Target Server
- **IP Address**: $mcpServerIP
- **Security Score**: $securityPercentage% ($securityLevel)

## Port & Service Exposure Analysis

### Critical Services
$(foreach ($port in $criticalPorts.Keys) {
    $status = if ($exposedCriticalPorts -contains $port) { "EXPOSED" } else { "CLOSED" }
    $risk = $criticalPorts[$port].Risk
    "- **Port $port ($($criticalPorts[$port].Service))**: $status - Risk: $risk"
})

### Additional Exposed Ports
$(if ($additionalExposedPorts.Count -gt 0) {
    foreach ($port in $additionalExposedPorts) {
        "- **Port $port**: Exposed"
    }
} else {
    "- No additional commonly targeted ports found open"
})

## Security Configuration Analysis

### HTTP Security Headers
$(if ($securityAnalysis.SecurityHeaders -and $securityAnalysis.SecurityHeaders.GetType().Name -ne "String") {
    foreach ($header in $securityAnalysis.SecurityHeaders.Keys) {
        $status = if ($securityAnalysis.SecurityHeaders[$header].Present) { "✅ Configured" } else { "❌ Missing" }
        $risk = $securityAnalysis.SecurityHeaders[$header].Risk
        "- **$header**: $status - Risk: $risk"
    }
} else {
    "- Unable to analyze security headers"
})

### HTTPS/TLS Configuration
- **HTTPS Available**: $(if ($securityAnalysis.HTTPS.Available) { "✅ Yes" } else { "❌ No" })
$(if (-not $securityAnalysis.HTTPS.Available) {
    "- **Issue**: $($securityAnalysis.HTTPS.Error)"
})

### MCP Service Security
- **Method Restriction**: $(if ($securityAnalysis.MCPSecurity.MethodRestriction -eq $true) { "✅ Implemented" } else { "⚠️ Not confirmed" })
- **Information Leakage**: $(if ($securityAnalysis.MCPSecurity.InformationLeakage -eq $false) { "✅ Protected" } else { "⚠️ Potential risk" })
- **Assessment**: $($securityAnalysis.MCPSecurity.Assessment)

## Network Security Assessment
- **Total Exposed Ports**: $totalExposedPorts
- **Network Exposure Risk**: $exposureRisk
- **Service Banner Risk**: $(if ($securityAnalysis.ServiceBanner.Risk) { $securityAnalysis.ServiceBanner.Risk } else { "Not assessed" })

## Security Score Breakdown
- **Port Security**: $portScore/25 points
- **Security Headers**: $headerScore/20 points
- **HTTPS Configuration**: $httpsScore/20 points
- **Service Security**: $serviceScore/20 points
- **Network Security**: $networkScore/15 points
- **Total Score**: $securityScore/100 points ($securityPercentage%)

## Risk Assessment

### High Priority Issues
$(if ($highPriorityIssues.Count -gt 0) {
    foreach ($issue in $highPriorityIssues) {
        "- ❌ $issue"
    }
} else {
    "- ✅ No critical security issues identified"
})

### Medium Priority Recommendations
- ⚠️ Implement comprehensive logging and monitoring
- ⚠️ Set up intrusion detection system
- ⚠️ Regular security updates and patches
- ⚠️ Network segmentation and firewall rules

## Security Recommendations

### Immediate Actions
$(if ($securityPercentage -ge 80) {
    "✅ Security posture is strong - maintain current configurations
✅ Implement regular security monitoring
✅ Plan for security updates and patches"
} elseif ($securityPercentage -ge 60) {
    "⚠️ Address high priority security issues
⚠️ Implement missing security headers
⚠️ Review and strengthen access controls"
} else {
    "❌ Immediate security improvements required
❌ Implement HTTPS and security headers
❌ Review and restrict port exposure"
})

### Long-term Security Strategy
1. **Security Monitoring**
   - Implement SIEM (Security Information and Event Management)
   - Set up automated security alerting
   - Regular security log review

2. **Access Control**
   - Implement multi-factor authentication
   - Regular access review and updates
   - Principle of least privilege

3. **Infrastructure Security**
   - Network segmentation and VPNs
   - Regular penetration testing
   - Vulnerability management program

4. **Compliance & Governance**
   - Security policy development
   - Regular security training
   - Incident response planning

## Next Steps
1. Address high priority security issues immediately
2. Implement security monitoring and alerting
3. Establish regular security review processes
4. Plan for security compliance requirements

---
*Generated by MCP Server Security Analysis Tool*
*Status: Security Analysis Complete*
"@
    
    $reportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "reports\mcp_security_analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    # Ensure reports directory exists
    $reportsDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host "`n📝 Security analysis report saved: $reportPath" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Security analysis failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "           SECURITY ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue"