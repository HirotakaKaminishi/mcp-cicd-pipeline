#!/bin/bash
# Security Headers Testing Script

echo "==================================="
echo "    Security Headers Testing"
echo "==================================="

TARGET_URL="https://192.168.111.200"
HTTP_URL="http://192.168.111.200"

echo "Testing security headers for: $TARGET_URL"

# Function to test a specific header
test_header() {
    local header_name="$1"
    local expected_value="$2"
    local url="$3"
    
    echo ""
    echo "Testing: $header_name"
    echo "Expected: $expected_value"
    
    actual_value=$(curl -s -I "$url" | grep -i "$header_name" | cut -d' ' -f2- | tr -d '\r\n')
    
    if [ -n "$actual_value" ]; then
        echo "笨・Found: $actual_value"
        if [[ "$actual_value" == *"$expected_value"* ]]; then
            echo "笨・Value matches expected"
        else
            echo "笞・・ Value differs from expected"
        fi
    else
        echo "笶・Header not found"
    fi
}

# Test HTTPS availability
echo "Testing HTTPS availability..."
if curl -s -I "$TARGET_URL" > /dev/null 2>&1; then
    echo "笨・HTTPS is accessible"
    USE_HTTPS=true
else
    echo "笶・HTTPS not accessible, testing HTTP"
    TARGET_URL="$HTTP_URL"
    USE_HTTPS=false
fi

echo ""
echo "Target URL: $TARGET_URL"

# Test each security header
test_header "Strict-Transport-Security" "max-age=31536000" "$TARGET_URL"
test_header "Content-Security-Policy" "default-src" "$TARGET_URL"
test_header "X-Frame-Options" "DENY" "$TARGET_URL"
test_header "X-Content-Type-Options" "nosniff" "$TARGET_URL"
test_header "X-XSS-Protection" "1; mode=block" "$TARGET_URL"
test_header "Referrer-Policy" "strict-origin-when-cross-origin" "$TARGET_URL"
test_header "Permissions-Policy" "camera" "$TARGET_URL"

# Test for headers that should NOT be present
echo ""
echo "Testing for headers that should be hidden:"

check_hidden_header() {
    local header_name="$1"
    local url="$2"
    
    if curl -s -I "$url" | grep -qi "$header_name"; then
        echo "笞・・ $header_name: Found (should be hidden)"
    else
        echo "笨・$header_name: Hidden correctly"
    fi
}

check_hidden_header "Server: nginx" "$TARGET_URL"
check_hidden_header "X-Powered-By" "$TARGET_URL"

# Overall security score
echo ""
echo "==================================="
echo "    Security Headers Score"
echo "==================================="

total_headers=7
present_headers=0

headers_to_check=(
    "Strict-Transport-Security"
    "Content-Security-Policy"
    "X-Frame-Options"
    "X-Content-Type-Options"
    "X-XSS-Protection"
    "Referrer-Policy"
    "Permissions-Policy"
)

for header in "${headers_to_check[@]}"; do
    if curl -s -I "$TARGET_URL" | grep -qi "$header"; then
        ((present_headers++))
    fi
done

score=$((present_headers * 100 / total_headers))

echo "Security Headers Present: $present_headers/$total_headers"
echo "Security Score: $score%"

if [ $score -ge 85 ]; then
    echo "笨・Excellent security header configuration"
elif [ $score -ge 70 ]; then
    echo "笨・Good security header configuration"
elif [ $score -ge 50 ]; then
    echo "笞・・ Fair security header configuration"
else
    echo "笶・Poor security header configuration"
fi

# Additional security tests
echo ""
echo "==================================="
echo "    Additional Security Tests"
echo "==================================="

# Test HTTP to HTTPS redirect
if [ "$USE_HTTPS" = true ]; then
    echo "Testing HTTP to HTTPS redirect..."
    redirect_status=$(curl -s -o /dev/null -w "%{http_code}" "$HTTP_URL")
    if [ "$redirect_status" = "301" ] || [ "$redirect_status" = "302" ]; then
        echo "笨・HTTP to HTTPS redirect working ($redirect_status)"
    else
        echo "笞・・ HTTP to HTTPS redirect status: $redirect_status"
    fi
fi

# Test SSL configuration
if [ "$USE_HTTPS" = true ]; then
    echo ""
    echo "Testing SSL configuration..."
    if command -v openssl > /dev/null; then
        ssl_info=$(echo | openssl s_client -connect ${mcpServerIP}:443 -servername $mcpServerIP 2>/dev/null | openssl x509 -noout -text 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "笨・SSL certificate is valid"
        else
            echo "笞・・ SSL certificate validation failed"
        fi
    else
        echo "笞・・ OpenSSL not available for certificate testing"
    fi
fi

echo ""
echo "脂 Security headers testing completed!"
echo ""
echo "Recommendations:"
echo "1. Ensure all security headers are present and correctly configured"
echo "2. Test with security scanners like SecurityHeaders.com"
echo "3. Monitor security headers in production"
echo "4. Update CSP policy based on application requirements"
