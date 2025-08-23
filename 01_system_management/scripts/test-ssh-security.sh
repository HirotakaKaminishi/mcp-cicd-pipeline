#!/bin/bash
# SSH Security Testing Script

echo "==================================="
echo "    SSH Security Testing"
echo "==================================="

TARGET_HOST="192.168.111.200"
SSH_PORT="2222"
SSH_USER="mcp-admin"

echo "Testing SSH security for: $TARGET_HOST:$SSH_PORT"

# Function to test SSH configuration
test_ssh_config() {
    echo ""
    echo "Testing SSH configuration..."
    
    # Test if SSH is responding on new port
    if nc -z "$TARGET_HOST" "$SSH_PORT" 2>/dev/null; then
        echo "笨・SSH is responding on port $SSH_PORT"
    else
        echo "笶・SSH is not responding on port $SSH_PORT"
        return 1
    fi
    
    # Test SSH banner
    echo "Testing SSH banner..."
    ssh_banner=$(echo "" | nc "$TARGET_HOST" "$SSH_PORT" 2>/dev/null | head -1)
    if [[ "$ssh_banner" == *"SSH"* ]]; then
        echo "笨・SSH banner received"
    else
        echo "笞・・ SSH banner not detected"
    fi
    
    # Test SSH protocol version
    echo "Testing SSH protocol..."
    ssh_version=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$TARGET_HOST" -p "$SSH_PORT" exit 2>&1 | grep -i "protocol")
    if [[ "$ssh_version" == *"2"* ]]; then
        echo "笨・SSH Protocol 2 is being used"
    else
        echo "笞・・ SSH Protocol version unclear"
    fi
}

# Function to test fail2ban
test_fail2ban() {
    echo ""
    echo "Testing fail2ban configuration..."
    
    # Check if fail2ban is running
    if systemctl is-active --quiet fail2ban; then
        echo "笨・fail2ban service is running"
        
        # Check fail2ban status
        fail2ban_status=$(sudo fail2ban-client status 2>/dev/null)
        if [[ "$fail2ban_status" == *"sshd"* ]]; then
            echo "笨・SSH jail is active in fail2ban"
        else
            echo "笞・・ SSH jail not found in fail2ban"
        fi
        
        # Show current bans
        echo "Current fail2ban status:"
        sudo fail2ban-client status sshd 2>/dev/null || echo "Unable to get SSH jail status"
        
    else
        echo "笶・fail2ban service is not running"
    fi
}

# Function to test SSH hardening
test_ssh_hardening() {
    echo ""
    echo "Testing SSH hardening measures..."
    
    # Test password authentication (should fail)
    echo "Testing password authentication (should be disabled)..."
    password_test=$(ssh -o BatchMode=yes -o PasswordAuthentication=yes -o ConnectTimeout=5 "$SSH_USER@$TARGET_HOST" -p "$SSH_PORT" exit 2>&1)
    if [[ "$password_test" == *"Permission denied"* ]] || [[ "$password_test" == *"password"* ]]; then
        echo "笨・Password authentication is properly disabled"
    else
        echo "笞・・ Password authentication status unclear"
    fi
    
    # Test root login (should fail)
    echo "Testing root login (should be disabled)..."
    root_test=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$TARGET_HOST" -p "$SSH_PORT" exit 2>&1)
    if [[ "$root_test" == *"Permission denied"* ]]; then
        echo "笨・Root login is properly disabled"
    else
        echo "笞・・ Root login status unclear"
    fi
}

# Function to test key authentication
test_key_auth() {
    echo ""
    echo "Testing SSH key authentication..."
    
    if [ -f "~/.ssh/id_ed25519" ]; then
        echo "Testing key authentication..."
        key_test=$(ssh -i ~/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$TARGET_HOST" -p "$SSH_PORT" "echo 'Key auth successful'" 2>&1)
        if [[ "$key_test" == *"successful"* ]]; then
            echo "笨・SSH key authentication is working"
        else
            echo "笞・・ SSH key authentication test failed or requires 2FA"
        fi
    else
        echo "笞・・ SSH private key not found for testing"
    fi
}

# Function to security score calculation
calculate_security_score() {
    echo ""
    echo "==================================="
    echo "    SSH Security Score"
    echo "==================================="
    
    score=0
    max_score=100
    
    # Port change (10 points)
    if nc -z "$TARGET_HOST" "$SSH_PORT" 2>/dev/null; then
        score=$((score + 10))
        echo "笨・Custom SSH port: +10 points"
    fi
    
    # fail2ban (20 points)
    if systemctl is-active --quiet fail2ban; then
        score=$((score + 20))
        echo "笨・fail2ban active: +20 points"
    fi
    
    # Password auth disabled (25 points)
    password_disabled=$(ssh -o BatchMode=yes -o PasswordAuthentication=yes -o ConnectTimeout=5 "$SSH_USER@$TARGET_HOST" -p "$SSH_PORT" exit 2>&1)
    if [[ "$password_disabled" == *"Permission denied"* ]]; then
        score=$((score + 25))
        echo "笨・Password auth disabled: +25 points"
    fi
    
    # Root login disabled (25 points)
    root_disabled=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$TARGET_HOST" -p "$SSH_PORT" exit 2>&1)
    if [[ "$root_disabled" == *"Permission denied"* ]]; then
        score=$((score + 25))
        echo "笨・Root login disabled: +25 points"
    fi
    
    # Key authentication (20 points)
    if [ -f "~/.ssh/id_ed25519" ]; then
        score=$((score + 20))
        echo "笨・SSH key configured: +20 points"
    fi
    
    percentage=$((score * 100 / max_score))
    
    echo ""
    echo "SSH Security Score: $score/$max_score ($percentage%)"
    
    if [ $percentage -ge 85 ]; then
        echo "笨・Excellent SSH security configuration"
    elif [ $percentage -ge 70 ]; then
        echo "笨・Good SSH security configuration"
    elif [ $percentage -ge 50 ]; then
        echo "笞・・ Fair SSH security configuration"
    else
        echo "笶・Poor SSH security configuration"
    fi
}

# Run all tests
test_ssh_config
test_fail2ban
test_ssh_hardening
test_key_auth
calculate_security_score

echo ""
echo "==================================="
echo "    SSH Security Testing Complete"
echo "==================================="
echo ""
echo "Recommendations:"
echo "1. Ensure all security measures show as 笨・
echo "2. Monitor fail2ban logs regularly"
echo "3. Regularly update SSH keys"
echo "4. Consider implementing 2FA for additional security"
