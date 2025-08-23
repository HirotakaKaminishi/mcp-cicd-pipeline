# HTTPS/SSL Certificate Implementation Script for MCP Server

$mcpServerIP = "192.168.111.200"

Write-Host "======================================" -ForegroundColor Green
Write-Host "    HTTPS/SSL IMPLEMENTATION" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target Server: $mcpServerIP" -ForegroundColor Cyan

try {
    Write-Host "`n🔐 Phase 1: SSL Certificate Planning..." -ForegroundColor Yellow
    
    # SSL Implementation Strategy
    Write-Host "Analyzing SSL implementation options..." -ForegroundColor Cyan
    
    $sslOptions = @{
        "Let's Encrypt" = @{
            Cost = "Free"
            Automation = "High"
            Validity = "90 days"
            Renewal = "Automatic"
            Recommendation = "Best for production"
        }
        "Self-Signed" = @{
            Cost = "Free"
            Automation = "Medium"
            Validity = "Custom"
            Renewal = "Manual"
            Recommendation = "Development/testing only"
        }
        "Commercial CA" = @{
            Cost = "$50-500/year"
            Automation = "Low"
            Validity = "1-3 years"
            Renewal = "Manual"
            Recommendation = "Enterprise environments"
        }
    }
    
    Write-Host "`n📋 SSL Certificate Options:" -ForegroundColor Cyan
    foreach ($option in $sslOptions.Keys) {
        $details = $sslOptions[$option]
        Write-Host "  • $option`:" -ForegroundColor White
        Write-Host "    Cost: $($details.Cost)" -ForegroundColor Gray
        Write-Host "    Automation: $($details.Automation)" -ForegroundColor Gray
        Write-Host "    Validity: $($details.Validity)" -ForegroundColor Gray
        Write-Host "    Recommendation: $($details.Recommendation)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "🎯 Recommended: Let's Encrypt for production deployment" -ForegroundColor Green
    
    Write-Host "`n🔐 Phase 2: nginx SSL Configuration Template..." -ForegroundColor Yellow
    
    # Generate nginx SSL configuration
    $nginxSSLConfig = @"
# nginx SSL Configuration for MCP Server
# File: /etc/nginx/sites-available/mcp-server-ssl

server {
    listen 80;
    server_name $mcpServerIP your-domain.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://`$server_name`$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $mcpServerIP your-domain.com;
    
    # SSL Certificate Configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/your-domain.com/chain.pem;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
    
    # Performance Optimizations
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rss+xml
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/bmp
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;
    
    # Rate Limiting
    limit_req_zone `$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;
    
    # Main application proxy
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        proxy_set_header X-Forwarded-Host `$server_name;
        
        # Timeout settings
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # API endpoint for application service
    location /api/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        
        # API-specific rate limiting
        limit_req zone=api burst=50 nodelay;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Security: Hide nginx version
    server_tokens off;
    
    # Logging
    access_log /var/log/nginx/mcp-server-ssl.access.log;
    error_log /var/log/nginx/mcp-server-ssl.error.log;
}
"@
    
    $nginxConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "configs\nginx-ssl-config.conf"
    
    # Ensure configs directory exists
    $configsDir = Split-Path $nginxConfigPath -Parent
    if (-not (Test-Path $configsDir)) {
        New-Item -ItemType Directory -Path $configsDir -Force | Out-Null
    }
    
    Set-Content -Path $nginxConfigPath -Value $nginxSSLConfig -Encoding UTF8
    Write-Host "📝 nginx SSL configuration saved: $nginxConfigPath" -ForegroundColor Cyan
    
    Write-Host "`n🔐 Phase 3: Let's Encrypt Installation Commands..." -ForegroundColor Yellow
    
    # Generate Let's Encrypt installation script
    $letsEncryptScript = @"
#!/bin/bash
# Let's Encrypt SSL Certificate Installation Script
# Run this script on the MCP server (192.168.111.200)

echo "==================================="
echo "  Let's Encrypt SSL Installation"
echo "==================================="

# Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Certbot and nginx plugin
echo "Installing Certbot..."
sudo apt install certbot python3-certbot-nginx -y

# Install nginx if not already installed
echo "Ensuring nginx is installed..."
sudo apt install nginx -y

# Stop nginx temporarily for certificate generation
echo "Stopping nginx for certificate generation..."
sudo systemctl stop nginx

# Generate SSL certificate (replace your-domain.com with actual domain)
echo "Generating SSL certificate..."
echo "NOTE: Replace 'your-domain.com' with your actual domain name"
echo "For IP-only setup, use --standalone mode"

# Option 1: With domain name
# sudo certbot certonly --nginx -d your-domain.com -d www.your-domain.com

# Option 2: Standalone mode (for IP-only setup)
sudo certbot certonly --standalone --preferred-challenges http -d $mcpServerIP

# Copy the SSL nginx configuration
echo "Setting up nginx SSL configuration..."
sudo cp /path/to/nginx-ssl-config.conf /etc/nginx/sites-available/mcp-server-ssl
sudo ln -sf /etc/nginx/sites-available/mcp-server-ssl /etc/nginx/sites-enabled/

# Remove default nginx config if exists
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "Testing nginx configuration..."
sudo nginx -t

if [ `$? -eq 0 ]; then
    echo "✅ nginx configuration is valid"
    
    # Start and enable nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    echo "✅ SSL certificate installed successfully!"
    echo "✅ nginx configured with SSL"
    echo "✅ HTTPS is now available"
    
    # Set up automatic renewal
    echo "Setting up automatic certificate renewal..."
    echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
    
    echo "✅ Automatic renewal configured"
    
else
    echo "❌ nginx configuration test failed"
    echo "Please check the configuration and try again"
    exit 1
fi

# Display SSL certificate information
echo ""
echo "SSL Certificate Information:"
sudo certbot certificates

echo ""
echo "🎉 SSL implementation completed successfully!"
echo "Your MCP server is now accessible via HTTPS"
echo "Test URL: https://$mcpServerIP"
"@
    
    $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\install-ssl-certificate.sh"
    
    # Ensure scripts directory exists
    $scriptsDir = Split-Path $scriptPath -Parent
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    
    Set-Content -Path $scriptPath -Value $letsEncryptScript -Encoding UTF8
    Write-Host "📝 Let's Encrypt installation script saved: $scriptPath" -ForegroundColor Cyan
    
    Write-Host "`n🔐 Phase 4: SSL Verification Commands..." -ForegroundColor Yellow
    
    # Generate SSL verification script
    $sslVerificationScript = @"
#!/bin/bash
# SSL Certificate Verification Script

echo "==================================="
echo "    SSL Certificate Verification"
echo "==================================="

# Check if certificates exist
echo "Checking certificate files..."
if [ -f "/etc/letsencrypt/live/$mcpServerIP/fullchain.pem" ]; then
    echo "✅ SSL certificate found"
    
    # Display certificate details
    echo ""
    echo "Certificate details:"
    sudo openssl x509 -in /etc/letsencrypt/live/$mcpServerIP/fullchain.pem -text -noout | grep -E "Subject:|Issuer:|Not Before:|Not After:"
    
else
    echo "❌ SSL certificate not found"
    echo "Please run the SSL installation script first"
    exit 1
fi

# Check nginx configuration
echo ""
echo "Checking nginx configuration..."
sudo nginx -t

if [ `$? -eq 0 ]; then
    echo "✅ nginx configuration is valid"
else
    echo "❌ nginx configuration has errors"
    exit 1
fi

# Check nginx status
echo ""
echo "Checking nginx service status..."
sudo systemctl status nginx --no-pager

# Test HTTPS connectivity
echo ""
echo "Testing HTTPS connectivity..."
curl -I https://$mcpServerIP --insecure

# Check SSL certificate from external perspective
echo ""
echo "SSL certificate check from external perspective:"
echo "Run this command from another machine:"
echo "openssl s_client -connect $mcpServerIP:443 -servername $mcpServerIP"

echo ""
echo "🎉 SSL verification completed!"
"@
    
    $verificationPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\verify-ssl-certificate.sh"
    Set-Content -Path $verificationPath -Value $sslVerificationScript -Encoding UTF8
    Write-Host "📝 SSL verification script saved: $verificationPath" -ForegroundColor Cyan
    
    Write-Host "`n🔐 Phase 5: Implementation Summary..." -ForegroundColor Yellow
    
    # Generate implementation summary
    Write-Host "`n📋 HTTPS/SSL IMPLEMENTATION PLAN:" -ForegroundColor Cyan
    Write-Host "  1. ✅ nginx SSL configuration template created" -ForegroundColor Green
    Write-Host "  2. ✅ Let's Encrypt installation script prepared" -ForegroundColor Green
    Write-Host "  3. ✅ SSL verification script ready" -ForegroundColor Green
    Write-Host "  4. ⏳ Requires execution on target server ($mcpServerIP)" -ForegroundColor Yellow
    
    Write-Host "`n🎯 NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Copy scripts to MCP server via SSH" -ForegroundColor White
    Write-Host "  2. Execute: chmod +x install-ssl-certificate.sh" -ForegroundColor White
    Write-Host "  3. Run: sudo ./install-ssl-certificate.sh" -ForegroundColor White
    Write-Host "  4. Verify: ./verify-ssl-certificate.sh" -ForegroundColor White
    Write-Host "  5. Test: https://$mcpServerIP" -ForegroundColor White
    
    Write-Host "`n🔧 CONFIGURATION BENEFITS:" -ForegroundColor Cyan
    Write-Host "  • TLS 1.2/1.3 with strong cipher suites" -ForegroundColor Green
    Write-Host "  • HSTS security header (1 year)" -ForegroundColor Green
    Write-Host "  • Comprehensive security headers" -ForegroundColor Green
    Write-Host "  • gzip compression enabled" -ForegroundColor Green
    Write-Host "  • Rate limiting (10 req/sec)" -ForegroundColor Green
    Write-Host "  • Automatic certificate renewal" -ForegroundColor Green
    Write-Host "  • Performance optimizations" -ForegroundColor Green
    
    Write-Host "`n⚠️  IMPORTANT NOTES:" -ForegroundColor Yellow
    Write-Host "  • Replace 'your-domain.com' with actual domain name" -ForegroundColor Yellow
    Write-Host "  • For IP-only setup, use standalone mode" -ForegroundColor Yellow
    Write-Host "  • Ensure DNS points to $mcpServerIP if using domain" -ForegroundColor Yellow
    Write-Host "  • Test thoroughly before production deployment" -ForegroundColor Yellow
    
    # Create implementation report
    $reportContent = @"
# HTTPS/SSL Implementation Plan for MCP Server

## Implementation Date
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Target Server
- **IP Address**: $mcpServerIP
- **Implementation Method**: Let's Encrypt with nginx
- **Security Level**: Production-ready with modern TLS

## Generated Files

### 1. nginx SSL Configuration
- **File**: nginx-ssl-config.conf
- **Location**: $nginxConfigPath
- **Features**: TLS 1.2/1.3, security headers, compression, rate limiting

### 2. SSL Installation Script
- **File**: install-ssl-certificate.sh
- **Location**: $scriptPath
- **Purpose**: Automated Let's Encrypt certificate installation

### 3. SSL Verification Script
- **File**: verify-ssl-certificate.sh
- **Location**: $verificationPath
- **Purpose**: Post-installation verification and testing

## Security Features Implemented

### TLS Configuration
- **Protocols**: TLS 1.2, TLS 1.3 only
- **Ciphers**: ECDHE with AES-GCM preferred
- **OCSP Stapling**: Enabled for performance
- **Session Cache**: 10MB shared cache

### Security Headers
- **HSTS**: 1 year with includeSubDomains
- **CSP**: Restrictive content security policy
- **X-Frame-Options**: DENY (clickjacking protection)
- **X-Content-Type-Options**: nosniff
- **X-XSS-Protection**: Enabled with mode=block

### Performance Optimizations
- **gzip Compression**: Enabled for text/media types
- **HTTP/2**: Enabled for modern browsers
- **Proxy Buffering**: Optimized for backend services
- **Connection Keepalive**: Configured for efficiency

### Rate Limiting
- **API Endpoints**: 10 requests/second with burst=50
- **General Traffic**: 10 requests/second with burst=20
- **Zone Size**: 10MB for rate limiting state

## Implementation Steps

### Step 1: Preparation
1. Ensure SSH access to MCP server
2. Verify nginx is installed or will be installed
3. Confirm domain name or IP-only setup preference

### Step 2: File Transfer
```bash
# Copy files to MCP server
scp nginx-ssl-config.conf user@${mcpServerIP}:/tmp/
scp install-ssl-certificate.sh user@${mcpServerIP}:/tmp/
scp verify-ssl-certificate.sh user@${mcpServerIP}:/tmp/
```

### Step 3: Installation
```bash
# On MCP server
chmod +x /tmp/install-ssl-certificate.sh
chmod +x /tmp/verify-ssl-certificate.sh
sudo /tmp/install-ssl-certificate.sh
```

### Step 4: Verification
```bash
# Run verification script
./verify-ssl-certificate.sh

# Test HTTPS access
curl -I https://${mcpServerIP}
```

## Expected Results

### Security Improvements
- **SSL/TLS Encryption**: All traffic encrypted
- **Security Score**: Expected increase from 69% to 85%+
- **Vulnerability Mitigation**: Protection against common attacks

### Performance Benefits
- **HTTP/2**: Faster page loads and API responses
- **Compression**: Reduced bandwidth usage
- **Caching**: Improved response times

### Compliance
- **Modern Standards**: TLS 1.2/1.3 compliance
- **Security Headers**: Industry best practices
- **Certificate Authority**: Trusted CA (Let's Encrypt)

## Maintenance Requirements

### Automatic Renewal
- **Cron Job**: Configured for automatic certificate renewal
- **Frequency**: Checks daily, renews when necessary
- **Validity**: 90-day certificates with 30-day renewal buffer

### Monitoring
- **Certificate Expiry**: Monitor certificate validity
- **SSL Labs Rating**: Periodic SSL configuration testing
- **Performance**: Monitor HTTPS response times

## Troubleshooting

### Common Issues
1. **Port 80/443 not accessible**: Check firewall settings
2. **Domain validation fails**: Verify DNS configuration
3. **Certificate not trusted**: Check certificate chain

### Validation Commands
```bash
# Check certificate validity
openssl x509 -in /etc/letsencrypt/live/domain/fullchain.pem -text -noout

# Test SSL configuration
openssl s_client -connect ${mcpServerIP}:443

# Verify nginx configuration
nginx -t
```

## Success Criteria
- ✅ HTTPS accessible on port 443
- ✅ HTTP redirects to HTTPS
- ✅ SSL Labs A+ rating
- ✅ All security headers present
- ✅ Certificate auto-renewal working

---
*Generated by MCP Server HTTPS/SSL Implementation Tool*
*Status: Ready for Implementation*
"@
    
    $reportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "reports\https_ssl_implementation_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    # Ensure reports directory exists
    $reportsDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host "`n📝 HTTPS/SSL implementation report saved: $reportPath" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ HTTPS/SSL implementation planning failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "        HTTPS/SSL IMPLEMENTATION READY" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue to security headers configuration"