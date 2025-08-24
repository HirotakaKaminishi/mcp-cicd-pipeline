#!/bin/bash
# Vibe-Kanban Integration Verification Script

echo "🔍 Vibe-Kanban Integration Verification"
echo "======================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected_code=$3
    
    echo -n "Testing $name... "
    response=$(curl -s -o /dev/null -w "%{http_code}" $url)
    
    if [ "$response" == "$expected_code" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (HTTP $response)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC} (Expected $expected_code, got $response)"
        ((TESTS_FAILED++))
    fi
}

# Function to test container status
test_container() {
    local name=$1
    
    echo -n "Checking container $name... "
    if docker ps --format "table {{.Names}}" | grep -q $name; then
        status=$(docker inspect -f '{{.State.Status}}' $name)
        if [ "$status" == "running" ]; then
            echo -e "${GREEN}✓ RUNNING${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠ STATUS: $status${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        ((TESTS_FAILED++))
    fi
}

# Function to test network connectivity
test_network() {
    local container=$1
    local target=$2
    
    echo -n "Testing network from $container to $target... "
    if docker exec $container ping -c 1 -W 2 $target > /dev/null 2>&1; then
        echo -e "${GREEN}✓ CONNECTED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ UNREACHABLE${NC}"
        ((TESTS_FAILED++))
    fi
}

echo ""
echo "1. Container Status Tests"
echo "-------------------------"
test_container "vibe-kanban"
test_container "mcp-server"
test_container "nginx-proxy"

echo ""
echo "2. Network Connectivity Tests"
echo "-----------------------------"
test_network "vibe-kanban" "mcp-server"
test_network "vibe-kanban" "nginx-proxy"

echo ""
echo "3. HTTP Endpoint Tests"
echo "----------------------"
test_endpoint "Vibe-Kanban UI" "http://localhost:3001" "200"
test_endpoint "MCP Server" "http://localhost:8080" "200"
test_endpoint "Nginx Proxy" "http://localhost:80" "200"

echo ""
echo "4. Integration Tests"
echo "--------------------"
# Test if vibe-kanban can reach MCP server internally
echo -n "Testing vibe-kanban -> MCP integration... "
if docker exec vibe-kanban curl -s -f http://mcp-server:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ INTEGRATED${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo "======================================="
echo "Verification Summary"
echo "======================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Vibe-Kanban is fully integrated.${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Please check the configuration.${NC}"
    exit 1
fi