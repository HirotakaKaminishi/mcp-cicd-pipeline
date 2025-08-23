#!/bin/bash
# nginx Performance Testing Script

echo "==================================="
echo "    nginx Performance Testing"
echo "==================================="

TARGET_HOST="192.168.111.200"
TARGET_URL="http://$TARGET_HOST"
API_URL="http://$TARGET_HOST/api"

echo "Testing nginx performance for: $TARGET_HOST"

# Function to test response times
test_response_times() {
    echo ""
    echo "Testing response times..."
    
    urls=(
        "$TARGET_URL/"
        "$TARGET_URL/nginx-health"
        "$API_URL/health"
        "$API_URL/info"
    )
    
    for url in "${urls[@]}"; do
        echo "Testing: $url"
        
        # Test 5 times and calculate average
        total_time=0
        success_count=0
        
        for i in {1..5}; do
            response_time=$(curl -s -o /dev/null -w "%{time_total}" "$url" 2>/dev/null)
            if [ $? -eq 0 ]; then
                total_time=$(echo "$total_time + $response_time" | bc -l)
                ((success_count++))
            fi
        done
        
        if [ $success_count -gt 0 ]; then
            avg_time=$(echo "scale=3; $total_time / $success_count" | bc -l)
            echo "  Average response time: $avg_time seconds (Success: $success_count/5)"
        else
            echo "  笶・All requests failed"
        fi
    done
}

# Function to test compression
test_compression() {
    echo ""
    echo "Testing compression..."
    
    # Test gzip compression
    gzip_test=$(curl -s -H "Accept-Encoding: gzip" -I "$TARGET_URL/" | grep -i "content-encoding: gzip")
    if [ -n "$gzip_test" ]; then
        echo "笨・gzip compression is working"
    else
        echo "笞・・ gzip compression not detected"
    fi
    
    # Test compression ratio
    uncompressed_size=$(curl -s "$TARGET_URL/" | wc -c)
    compressed_size=$(curl -s -H "Accept-Encoding: gzip" "$TARGET_URL/" | wc -c)
    
    if [ $uncompressed_size -gt 0 ] && [ $compressed_size -gt 0 ]; then
        ratio=$(echo "scale=2; (1 - $compressed_size / $uncompressed_size) * 100" | bc -l)
        echo "  Compression ratio: $ratio%"
    fi
}

# Function to test caching
test_caching() {
    echo ""
    echo "Testing caching..."
    
    # Test cache headers
    cache_headers=$(curl -s -I "$TARGET_URL/" | grep -i "cache-control\|expires\|etag")
    if [ -n "$cache_headers" ]; then
        echo "笨・Cache headers present:"
        echo "$cache_headers" | sed 's/^/  /'
    else
        echo "笞・・ No cache headers detected"
    fi
    
    # Test static file caching
    static_cache=$(curl -s -I "$TARGET_URL/favicon.ico" | grep -i "cache-control")
    if [ -n "$static_cache" ]; then
        echo "笨・Static file caching configured"
    else
        echo "笞・・ Static file caching not detected"
    fi
}

# Function to test security headers
test_security_headers() {
    echo ""
    echo "Testing security headers..."
    
    security_headers=(
        "Strict-Transport-Security"
        "X-Content-Type-Options"
        "X-Frame-Options"
        "X-XSS-Protection"
        "Content-Security-Policy"
    )
    
    present_headers=0
    total_headers=${#security_headers[@]}
    
    for header in "${security_headers[@]}"; do
        if curl -s -I "$TARGET_URL/" | grep -qi "$header"; then
            echo "  笨・$header: Present"
            ((present_headers++))
        else
            echo "  笶・$header: Missing"
        fi
    done
    
    echo "Security headers: $present_headers/$total_headers present"
}

# Function to test rate limiting
test_rate_limiting() {
    echo ""
    echo "Testing rate limiting..."
    
    # Send multiple requests quickly
    rate_limit_triggered=false
    
    for i in {1..15}; do
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL/api/health" 2>/dev/null)
        if [ "$response_code" = "429" ]; then
            rate_limit_triggered=true
            break
        fi
        sleep 0.1
    done
    
    if [ "$rate_limit_triggered" = true ]; then
        echo "笨・Rate limiting is working (429 response triggered)"
    else
        echo "笞・・ Rate limiting not triggered (may need adjustment)"
    fi
}

# Function to test load capacity
test_load_capacity() {
    echo ""
    echo "Testing load capacity..."
    
    if command -v ab &> /dev/null; then
        echo "Running Apache Bench test (100 requests, 10 concurrent)..."
        ab_result=$(ab -n 100 -c 10 "$TARGET_URL/" 2>/dev/null)
        
        # Extract key metrics
        rps=$(echo "$ab_result" | grep "Requests per second" | awk '{print $4}')
        response_time=$(echo "$ab_result" | grep "Time per request" | head -1 | awk '{print $4}')
        
        if [ -n "$rps" ]; then
            echo "  Requests per second: $rps"
            echo "  Average response time: $response_time ms"
        fi
    else
        echo "笞・・ Apache Bench (ab) not available for load testing"
        echo "  Install with: sudo apt install apache2-utils"
    fi
}

# Function to check nginx status
check_nginx_status() {
    echo ""
    echo "Checking nginx status..."
    
    # Service status
    if systemctl is-active --quiet nginx; then
        echo "笨・nginx service is running"
    else
        echo "笶・nginx service is not running"
        return 1
    fi
    
    # Configuration test
    if nginx -t &>/dev/null; then
        echo "笨・nginx configuration is valid"
    else
        echo "笶・nginx configuration has errors"
        nginx -t
    fi
    
    # Connection count
    if command -v ss &> /dev/null; then
        connections=$(ss -tuln | grep -E ':80|:443' | wc -l)
        echo "Active listening ports: $connections"
    fi
    
    # Memory usage
    memory_usage=$(ps aux | grep nginx | grep -v grep | awk '{sum += $6} END {print sum/1024}')
    echo "nginx memory usage: ${memory_usage} MB"
}

# Function to generate performance report
generate_performance_report() {
    echo ""
    echo "==================================="
    echo "    Performance Test Summary"
    echo "==================================="
    
    # Calculate overall score
    score=0
    max_score=100
    
    # Response time score (25 points)
    avg_response=$(curl -s -o /dev/null -w "%{time_total}" "$TARGET_URL/" 2>/dev/null)
    if [ -n "$avg_response" ]; then
        if (( $(echo "$avg_response < 0.1" | bc -l) )); then
            score=$((score + 25))
            echo "笨・Response time: Excellent ($avg_response s) - 25/25 points"
        elif (( $(echo "$avg_response < 0.2" | bc -l) )); then
            score=$((score + 20))
            echo "笨・Response time: Good ($avg_response s) - 20/25 points"
        elif (( $(echo "$avg_response < 0.5" | bc -l) )); then
            score=$((score + 15))
            echo "笞・・ Response time: Fair ($avg_response s) - 15/25 points"
        else
            score=$((score + 10))
            echo "笶・Response time: Poor ($avg_response s) - 10/25 points"
        fi
    fi
    
    # Compression score (20 points)
    if curl -s -H "Accept-Encoding: gzip" -I "$TARGET_URL/" | grep -qi "content-encoding: gzip"; then
        score=$((score + 20))
        echo "笨・Compression: Working - 20/20 points"
    else
        echo "笶・Compression: Not working - 0/20 points"
    fi
    
    # Security headers score (25 points)
    header_count=0
    for header in "Strict-Transport-Security" "X-Content-Type-Options" "X-Frame-Options" "X-XSS-Protection" "Content-Security-Policy"; do
        if curl -s -I "$TARGET_URL/" | grep -qi "$header"; then
            ((header_count++))
        fi
    done
    security_score=$((header_count * 5))
    score=$((score + security_score))
    echo "笨・Security headers: $header_count/5 present - $security_score/25 points"
    
    # Service health score (20 points)
    if systemctl is-active --quiet nginx && nginx -t &>/dev/null; then
        score=$((score + 20))
        echo "笨・Service health: Excellent - 20/20 points"
    else
        echo "笶・Service health: Issues detected - 0/20 points"
    fi
    
    # Caching score (10 points)
    if curl -s -I "$TARGET_URL/" | grep -qi "cache-control"; then
        score=$((score + 10))
        echo "笨・Caching: Configured - 10/10 points"
    else
        echo "笶・Caching: Not configured - 0/10 points"
    fi
    
    percentage=$((score * 100 / max_score))
    
    echo ""
    echo "nginx Performance Score: $score/$max_score ($percentage%)"
    
    if [ $percentage -ge 85 ]; then
        echo "脂 Excellent nginx performance!"
    elif [ $percentage -ge 70 ]; then
        echo "笨・Good nginx performance"
    elif [ $percentage -ge 50 ]; then
        echo "笞・・ Fair nginx performance - optimization needed"
    else
        echo "笶・Poor nginx performance - significant optimization required"
    fi
}

# Run all tests
check_nginx_status
test_response_times
test_compression
test_caching
test_security_headers
test_rate_limiting
test_load_capacity
generate_performance_report

echo ""
echo "==================================="
echo "    Performance Testing Complete"
echo "==================================="
echo ""
echo "Recommendations:"
echo "1. Monitor performance metrics regularly"
echo "2. Adjust rate limits based on traffic patterns"
echo "3. Optimize cache settings for your content"
echo "4. Consider CDN integration for static assets"
echo "5. Set up automated performance monitoring"
