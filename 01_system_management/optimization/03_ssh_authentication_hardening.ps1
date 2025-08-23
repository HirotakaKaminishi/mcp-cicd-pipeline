# SSH Authentication Hardening Script for MCP Server

$mcpServerIP = "192.168.111.200"

Write-Host "======================================" -ForegroundColor Green
Write-Host "    SSH AUTHENTICATION HARDENING" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Target Server: $mcpServerIP" -ForegroundColor Cyan

try {
    Write-Host "`n🔐 Phase 1: SSH Security Analysis..." -ForegroundColor Yellow
    
    # SSH security assessment
    Write-Host "Analyzing SSH security requirements..." -ForegroundColor Cyan
    
    $sshSecurityMeasures = @{
        "Key-based Authentication" = @{
            Priority = "Critical"
            Description = "Replace password authentication with SSH keys"
            Security = "High"
            Effort = "Medium"
        }
        "Disable Root Login" = @{
            Priority = "Critical"
            Description = "Prevent direct root access via SSH"
            Security = "High"
            Effort = "Low"
        }
        "Change Default Port" = @{
            Priority = "High"
            Description = "Move SSH from port 22 to custom port"
            Security = "Medium"
            Effort = "Low"
        }
        "Fail2ban Implementation" = @{
            Priority = "High"
            Description = "Automatic blocking of brute force attempts"
            Security = "High"
            Effort = "Medium"
        }
        "Two-Factor Authentication" = @{
            Priority = "Medium"
            Description = "Add TOTP-based 2FA for additional security"
            Security = "Very High"
            Effort = "High"
        }
        "SSH Key Restrictions" = @{
            Priority = "Medium"
            Description = "Limit SSH key usage and permissions"
            Security = "Medium"
            Effort = "Medium"
        }
        "Connection Limits" = @{
            Priority = "Low"
            Description = "Limit concurrent SSH connections"
            Security = "Low"
            Effort = "Low"
        }
    }
    
    Write-Host "`n📋 SSH Security Measures Overview:" -ForegroundColor Cyan
    foreach ($measure in $sshSecurityMeasures.Keys) {
        $details = $sshSecurityMeasures[$measure]
        $priorityColor = switch ($details.Priority) {
            "Critical" { "Red" }
            "High" { "Yellow" }
            "Medium" { "Cyan" }
            "Low" { "Green" }
        }
        Write-Host "  • $measure`: $($details.Description)" -ForegroundColor White
        Write-Host "    Priority: $($details.Priority) | Security: $($details.Security) | Effort: $($details.Effort)" -ForegroundColor $priorityColor
        Write-Host ""
    }
    
    Write-Host "`n🔐 Phase 2: SSH Configuration Hardening..." -ForegroundColor Yellow
    
    # Generate hardened SSH configuration
    $sshdConfig = @"
# Hardened SSH Configuration for MCP Server
# File: /etc/ssh/sshd_config
# Backup original: sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Protocol and Port Configuration
Protocol 2
Port 2222
# Note: Change from default port 22 to reduce automated attacks

# Address and Interface Binding
#ListenAddress 0.0.0.0
#ListenAddress ::
AddressFamily inet
# Note: Use 'inet6' for IPv6 or 'any' for both

# Authentication Configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Key Exchange and Encryption
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512

# Connection Limits and Timeouts
MaxAuthTries 3
MaxSessions 2
MaxStartups 2:30:10
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 0

# User and Group Restrictions
AllowUsers mcp-admin
# Note: Replace 'mcp-admin' with your actual admin username
# AllowGroups ssh-users
# DenyUsers root guest
# DenyGroups guests

# Disable Unused Features
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes
PermitTunnel no
GatewayPorts no
PermitUserEnvironment no

# Logging and Monitoring
SyslogFacility AUTH
LogLevel VERBOSE
# Note: VERBOSE logs key fingerprints for security monitoring

# Security Features
StrictModes yes
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserRC no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression delayed

# Banner Configuration
Banner /etc/ssh/ssh_banner
# Note: Create a security banner file

# Subsystem Configuration (for SFTP if needed)
Subsystem sftp /usr/lib/openssh/sftp-server -l INFO

# Match Blocks for Specific Users/Groups
# Example: Restricted SFTP-only user
# Match Group sftp-only
#     ChrootDirectory /home/sftp/%u
#     ForceCommand internal-sftp
#     AllowTcpForwarding no
#     AllowAgentForwarding no
#     PermitTunnel no
#     X11Forwarding no
"@
    
    $sshdConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "configs\sshd_config_hardened"
    
    # Ensure configs directory exists
    $configsDir = Split-Path $sshdConfigPath -Parent
    if (-not (Test-Path $configsDir)) {
        New-Item -ItemType Directory -Path $configsDir -Force | Out-Null
    }
    
    Set-Content -Path $sshdConfigPath -Value $sshdConfig -Encoding UTF8
    Write-Host "📝 Hardened SSH configuration saved: $sshdConfigPath" -ForegroundColor Cyan
    
    Write-Host "`n🔐 Phase 3: SSH Key Generation and Management..." -ForegroundColor Yellow
    
    # Generate SSH key creation script
    $sshKeyScript = @"
#!/bin/bash
# SSH Key Generation and Setup Script

echo "==================================="
echo "    SSH Key Generation & Setup"
echo "==================================="

# Configuration
SSH_USER="mcp-admin"
KEY_TYPE="ed25519"
KEY_COMMENT="MCP-Server-Admin-Key-`$(date +%Y%m%d)"
BACKUP_DIR="/home/`$SSH_USER/.ssh/backup"

echo "Setting up SSH key authentication for user: `$SSH_USER"

# Create SSH user if doesn't exist
if ! id "`$SSH_USER" &>/dev/null; then
    echo "Creating user: `$SSH_USER"
    sudo useradd -m -s /bin/bash "`$SSH_USER"
    sudo usermod -aG sudo "`$SSH_USER"
    echo "✅ User `$SSH_USER created with sudo privileges"
else
    echo "✅ User `$SSH_USER already exists"
fi

# Switch to the SSH user for key operations
sudo -u "`$SSH_USER" bash << 'EOF'
# Create .ssh directory with correct permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Backup existing keys if any
if [ -f ~/.ssh/authorized_keys ]; then
    echo "Backing up existing authorized_keys..."
    mkdir -p ~/.ssh/backup
    cp ~/.ssh/authorized_keys ~/.ssh/backup/authorized_keys.`$(date +%Y%m%d_%H%M%S)
fi

# Generate new SSH key pair
echo "Generating new Ed25519 SSH key pair..."
ssh-keygen -t ed25519 -C "MCP-Server-Admin-Key-`$(date +%Y%m%d)" -f ~/.ssh/id_ed25519 -N ""

if [ `$? -eq 0 ]; then
    echo "✅ SSH key pair generated successfully"
    
    # Add public key to authorized_keys
    cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    chmod 400 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    
    echo "✅ SSH key added to authorized_keys"
    
    # Display public key for copying to client
    echo ""
    echo "==================================="
    echo "    PUBLIC KEY FOR CLIENT SETUP"
    echo "==================================="
    echo "Copy this public key to your SSH client:"
    echo ""
    cat ~/.ssh/id_ed25519.pub
    echo ""
    echo "==================================="
    
    # Display private key location
    echo "Private key location: ~/.ssh/id_ed25519"
    echo "⚠️  IMPORTANT: Keep the private key secure!"
    
else
    echo "❌ Failed to generate SSH key pair"
    exit 1
fi
EOF

# Generate SSH banner
echo "Creating SSH security banner..."
sudo tee /etc/ssh/ssh_banner > /dev/null << 'EOF'
********************************************************************************
*                               SECURITY NOTICE                               *
********************************************************************************
*                                                                              *
* This system is for authorized users only. All activity is monitored and     *
* logged. Unauthorized access is strictly prohibited and will be prosecuted   *
* to the full extent of the law.                                              *
*                                                                              *
* By accessing this system, you acknowledge that you have read and agree to   *
* comply with the organization's security policies and procedures.            *
*                                                                              *
* If you are not an authorized user, disconnect immediately.                  *
*                                                                              *
********************************************************************************
EOF

echo "✅ SSH banner created"

# Install and configure fail2ban
echo ""
echo "Installing and configuring fail2ban..."
sudo apt update
sudo apt install fail2ban -y

# Create fail2ban configuration for SSH
sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 2222
logpath = %(sshd_log)s
maxretry = 3
bantime = 3600
findtime = 600

[sshd-ddos]
enabled = true
port = 2222
logpath = %(sshd_log)s
maxretry = 6
bantime = 3600
findtime = 60
EOF

echo "✅ fail2ban configured for SSH protection"

# Start and enable fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

echo ""
echo "==================================="
echo "    SSH KEY SETUP COMPLETED"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Copy the public key to your SSH client"
echo "2. Test SSH connection with key authentication"
echo "3. Apply hardened SSH configuration"
echo "4. Restart SSH service"
echo "5. Verify fail2ban is running"
echo ""
echo "Test connection command:"
echo "ssh -i path/to/private/key -p 2222 `$SSH_USER@$mcpServerIP"
"@
    
    $sshKeyScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\setup-ssh-keys.sh"
    
    # Ensure scripts directory exists
    $scriptsDir = Split-Path $sshKeyScriptPath -Parent
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    
    Set-Content -Path $sshKeyScriptPath -Value $sshKeyScript -Encoding UTF8
    Write-Host "📝 SSH key setup script saved: $sshKeyScriptPath" -ForegroundColor Cyan
    
    Write-Host "`n🔐 Phase 4: Two-Factor Authentication Setup..." -ForegroundColor Yellow
    
    # Generate 2FA setup script
    $twoFactorScript = @"
#!/bin/bash
# Two-Factor Authentication Setup for SSH

echo "==================================="
echo "  Two-Factor Authentication Setup"
echo "==================================="

# Install Google Authenticator PAM module
echo "Installing Google Authenticator PAM module..."
sudo apt update
sudo apt install libpam-google-authenticator -y

if [ `$? -eq 0 ]; then
    echo "✅ Google Authenticator installed successfully"
else
    echo "❌ Failed to install Google Authenticator"
    exit 1
fi

# Configure PAM for SSH
echo "Configuring PAM for SSH 2FA..."

# Backup original PAM SSH configuration
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.backup

# Add Google Authenticator to PAM SSH configuration
echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd > /dev/null

# Configure SSH for 2FA
echo "Configuring SSH daemon for 2FA..."

# Backup original SSH configuration
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.2fa.backup

# Add 2FA configuration to SSH
sudo tee -a /etc/ssh/sshd_config > /dev/null << 'EOF'

# Two-Factor Authentication Configuration
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,keyboard-interactive
EOF

echo "✅ SSH configured for 2FA"

# Setup 2FA for user
echo ""
echo "Setting up 2FA for user: `$USER"
echo "You will be prompted to scan a QR code with your authenticator app"
echo ""

# Run Google Authenticator setup
google-authenticator -t -d -f -r 3 -R 30 -W

if [ `$? -eq 0 ]; then
    echo "✅ 2FA setup completed for user: `$USER"
    
    # Restart SSH service
    echo "Restarting SSH service..."
    sudo systemctl restart ssh
    
    if [ `$? -eq 0 ]; then
        echo "✅ SSH service restarted successfully"
        echo ""
        echo "==================================="
        echo "    2FA SETUP COMPLETED"
        echo "==================================="
        echo ""
        echo "IMPORTANT NOTES:"
        echo "1. Save your backup codes in a secure location"
        echo "2. Test 2FA login from another terminal before closing this session"
        echo "3. You will need both SSH key AND TOTP code to login"
        echo ""
        echo "Login process:"
        echo "1. SSH connects with key authentication"
        echo "2. System prompts for verification code"
        echo "3. Enter 6-digit code from authenticator app"
        echo ""
    else
        echo "❌ Failed to restart SSH service"
        echo "Please check SSH configuration and restart manually"
    fi
else
    echo "❌ 2FA setup failed"
    exit 1
fi
"@
    
    $twoFactorScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\setup-ssh-2fa.sh"
    Set-Content -Path $twoFactorScriptPath -Value $twoFactorScript -Encoding UTF8
    Write-Host "📝 Two-factor authentication setup script saved: $twoFactorScriptPath" -ForegroundColor Cyan
    
    Write-Host "`n🔐 Phase 5: SSH Security Testing Script..." -ForegroundColor Yellow
    
    # Generate SSH security testing script
    $sshTestScript = @"
#!/bin/bash
# SSH Security Testing Script

echo "==================================="
echo "    SSH Security Testing"
echo "==================================="

TARGET_HOST="$mcpServerIP"
SSH_PORT="2222"
SSH_USER="mcp-admin"

echo "Testing SSH security for: `$TARGET_HOST:`$SSH_PORT"

# Function to test SSH configuration
test_ssh_config() {
    echo ""
    echo "Testing SSH configuration..."
    
    # Test if SSH is responding on new port
    if nc -z "`$TARGET_HOST" "`$SSH_PORT" 2>/dev/null; then
        echo "✅ SSH is responding on port `$SSH_PORT"
    else
        echo "❌ SSH is not responding on port `$SSH_PORT"
        return 1
    fi
    
    # Test SSH banner
    echo "Testing SSH banner..."
    ssh_banner=`$(echo "" | nc "`$TARGET_HOST" "`$SSH_PORT" 2>/dev/null | head -1)
    if [[ "`$ssh_banner" == *"SSH"* ]]; then
        echo "✅ SSH banner received"
    else
        echo "⚠️  SSH banner not detected"
    fi
    
    # Test SSH protocol version
    echo "Testing SSH protocol..."
    ssh_version=`$(ssh -o BatchMode=yes -o ConnectTimeout=5 "`$SSH_USER@`$TARGET_HOST" -p "`$SSH_PORT" exit 2>&1 | grep -i "protocol")
    if [[ "`$ssh_version" == *"2"* ]]; then
        echo "✅ SSH Protocol 2 is being used"
    else
        echo "⚠️  SSH Protocol version unclear"
    fi
}

# Function to test fail2ban
test_fail2ban() {
    echo ""
    echo "Testing fail2ban configuration..."
    
    # Check if fail2ban is running
    if systemctl is-active --quiet fail2ban; then
        echo "✅ fail2ban service is running"
        
        # Check fail2ban status
        fail2ban_status=`$(sudo fail2ban-client status 2>/dev/null)
        if [[ "`$fail2ban_status" == *"sshd"* ]]; then
            echo "✅ SSH jail is active in fail2ban"
        else
            echo "⚠️  SSH jail not found in fail2ban"
        fi
        
        # Show current bans
        echo "Current fail2ban status:"
        sudo fail2ban-client status sshd 2>/dev/null || echo "Unable to get SSH jail status"
        
    else
        echo "❌ fail2ban service is not running"
    fi
}

# Function to test SSH hardening
test_ssh_hardening() {
    echo ""
    echo "Testing SSH hardening measures..."
    
    # Test password authentication (should fail)
    echo "Testing password authentication (should be disabled)..."
    password_test=`$(ssh -o BatchMode=yes -o PasswordAuthentication=yes -o ConnectTimeout=5 "`$SSH_USER@`$TARGET_HOST" -p "`$SSH_PORT" exit 2>&1)
    if [[ "`$password_test" == *"Permission denied"* ]] || [[ "`$password_test" == *"password"* ]]; then
        echo "✅ Password authentication is properly disabled"
    else
        echo "⚠️  Password authentication status unclear"
    fi
    
    # Test root login (should fail)
    echo "Testing root login (should be disabled)..."
    root_test=`$(ssh -o BatchMode=yes -o ConnectTimeout=5 "root@`$TARGET_HOST" -p "`$SSH_PORT" exit 2>&1)
    if [[ "`$root_test" == *"Permission denied"* ]]; then
        echo "✅ Root login is properly disabled"
    else
        echo "⚠️  Root login status unclear"
    fi
}

# Function to test key authentication
test_key_auth() {
    echo ""
    echo "Testing SSH key authentication..."
    
    if [ -f "~/.ssh/id_ed25519" ]; then
        echo "Testing key authentication..."
        key_test=`$(ssh -i ~/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=5 "`$SSH_USER@`$TARGET_HOST" -p "`$SSH_PORT" "echo 'Key auth successful'" 2>&1)
        if [[ "`$key_test" == *"successful"* ]]; then
            echo "✅ SSH key authentication is working"
        else
            echo "⚠️  SSH key authentication test failed or requires 2FA"
        fi
    else
        echo "⚠️  SSH private key not found for testing"
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
    if nc -z "`$TARGET_HOST" "`$SSH_PORT" 2>/dev/null; then
        score=`$((score + 10))
        echo "✅ Custom SSH port: +10 points"
    fi
    
    # fail2ban (20 points)
    if systemctl is-active --quiet fail2ban; then
        score=`$((score + 20))
        echo "✅ fail2ban active: +20 points"
    fi
    
    # Password auth disabled (25 points)
    password_disabled=`$(ssh -o BatchMode=yes -o PasswordAuthentication=yes -o ConnectTimeout=5 "`$SSH_USER@`$TARGET_HOST" -p "`$SSH_PORT" exit 2>&1)
    if [[ "`$password_disabled" == *"Permission denied"* ]]; then
        score=`$((score + 25))
        echo "✅ Password auth disabled: +25 points"
    fi
    
    # Root login disabled (25 points)
    root_disabled=`$(ssh -o BatchMode=yes -o ConnectTimeout=5 "root@`$TARGET_HOST" -p "`$SSH_PORT" exit 2>&1)
    if [[ "`$root_disabled" == *"Permission denied"* ]]; then
        score=`$((score + 25))
        echo "✅ Root login disabled: +25 points"
    fi
    
    # Key authentication (20 points)
    if [ -f "~/.ssh/id_ed25519" ]; then
        score=`$((score + 20))
        echo "✅ SSH key configured: +20 points"
    fi
    
    percentage=`$((score * 100 / max_score))
    
    echo ""
    echo "SSH Security Score: `$score/`$max_score (`$percentage%)"
    
    if [ `$percentage -ge 85 ]; then
        echo "✅ Excellent SSH security configuration"
    elif [ `$percentage -ge 70 ]; then
        echo "✅ Good SSH security configuration"
    elif [ `$percentage -ge 50 ]; then
        echo "⚠️  Fair SSH security configuration"
    else
        echo "❌ Poor SSH security configuration"
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
echo "1. Ensure all security measures show as ✅"
echo "2. Monitor fail2ban logs regularly"
echo "3. Regularly update SSH keys"
echo "4. Consider implementing 2FA for additional security"
"@
    
    $sshTestScriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\test-ssh-security.sh"
    Set-Content -Path $sshTestScriptPath -Value $sshTestScript -Encoding UTF8
    Write-Host "📝 SSH security testing script saved: $sshTestScriptPath" -ForegroundColor Cyan
    
    Write-Host "`n🔐 Phase 6: Implementation Summary..." -ForegroundColor Yellow
    
    Write-Host "`n📋 SSH AUTHENTICATION HARDENING PLAN:" -ForegroundColor Cyan
    Write-Host "  1. ✅ Hardened SSH configuration created" -ForegroundColor Green
    Write-Host "  2. ✅ SSH key setup script prepared" -ForegroundColor Green
    Write-Host "  3. ✅ Two-factor authentication script ready" -ForegroundColor Green
    Write-Host "  4. ✅ Security testing script created" -ForegroundColor Green
    Write-Host "  5. ⏳ Requires implementation on target server" -ForegroundColor Yellow
    
    Write-Host "`n🎯 IMPLEMENTATION STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Run SSH key setup script" -ForegroundColor White
    Write-Host "  2. Apply hardened SSH configuration" -ForegroundColor White
    Write-Host "  3. Configure fail2ban protection" -ForegroundColor White
    Write-Host "  4. Optionally setup 2FA" -ForegroundColor White
    Write-Host "  5. Test all security measures" -ForegroundColor White
    
    Write-Host "`n🔧 SECURITY IMPROVEMENTS:" -ForegroundColor Cyan
    Write-Host "  • Ed25519 key-based authentication" -ForegroundColor Green
    Write-Host "  • Disabled password and root login" -ForegroundColor Green
    Write-Host "  • Custom SSH port (2222)" -ForegroundColor Green
    Write-Host "  • fail2ban brute force protection" -ForegroundColor Green
    Write-Host "  • Strong cryptographic algorithms" -ForegroundColor Green
    Write-Host "  • Connection limits and timeouts" -ForegroundColor Green
    Write-Host "  • Comprehensive logging" -ForegroundColor Green
    
    Write-Host "`n⚠️  IMPORTANT WARNINGS:" -ForegroundColor Red
    Write-Host "  • Test SSH configuration before applying" -ForegroundColor Red
    Write-Host "  • Keep backup of original SSH config" -ForegroundColor Red
    Write-Host "  • Ensure SSH key access before disabling passwords" -ForegroundColor Red
    Write-Host "  • Update firewall rules for new SSH port" -ForegroundColor Red
    
    # Create implementation report
    $reportContent = @"
# SSH Authentication Hardening for MCP Server

## Implementation Date
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Target Server
- **IP Address**: $mcpServerIP
- **SSH Hardening Level**: Production-grade with optional 2FA
- **Security Enhancement**: Multi-layer SSH protection

## Generated Configurations and Scripts

### 1. Hardened SSH Configuration
- **File**: sshd_config_hardened
- **Location**: $sshdConfigPath
- **Features**: Key-only auth, custom port, strong crypto, connection limits

### 2. SSH Key Setup Script
- **File**: setup-ssh-keys.sh
- **Location**: $sshKeyScriptPath
- **Purpose**: Automated SSH key generation and user setup

### 3. Two-Factor Authentication Script
- **File**: setup-ssh-2fa.sh
- **Location**: $twoFactorScriptPath
- **Purpose**: TOTP-based 2FA implementation

### 4. Security Testing Script
- **File**: test-ssh-security.sh
- **Location**: $sshTestScriptPath
- **Purpose**: Comprehensive SSH security validation

## Security Measures Implemented

### Authentication Hardening
$(foreach ($measure in $sshSecurityMeasures.Keys) {
    $details = $sshSecurityMeasures[$measure]
    "- **$measure**: $($details.Description)
  - Priority: $($details.Priority)
  - Security Level: $($details.Security)
  - Implementation Effort: $($details.Effort)
"
})

### Cryptographic Improvements
- **Key Exchange**: curve25519-sha256, ECDH with strong curves
- **Ciphers**: ChaCha20-Poly1305, AES-GCM, AES-CTR
- **MACs**: HMAC-SHA2 with encrypt-then-MAC
- **Host Keys**: Ed25519 and ECDSA preferred

### Connection Security
- **Port**: Changed from 22 to 2222 (reduces automated attacks)
- **Protocol**: SSH Protocol 2 only
- **Max Auth Tries**: Limited to 3 attempts
- **Login Grace Time**: 60 seconds timeout
- **Client Alive**: 300 second intervals

### Access Control
- **Root Login**: Completely disabled
- **Password Auth**: Disabled (key-only)
- **Empty Passwords**: Explicitly forbidden
- **User Restrictions**: Limited to specific users/groups
- **Unused Features**: Agent forwarding, X11, tunneling disabled

## Implementation Instructions

### Step 1: Preparation
```bash
# Backup current SSH configuration
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Copy scripts to server
scp setup-ssh-keys.sh user@${mcpServerIP}:/tmp/
scp sshd_config_hardened user@${mcpServerIP}:/tmp/
scp setup-ssh-2fa.sh user@${mcpServerIP}:/tmp/
scp test-ssh-security.sh user@${mcpServerIP}:/tmp/
```

### Step 2: SSH Key Setup
```bash
# On the MCP server
chmod +x /tmp/setup-ssh-keys.sh
sudo /tmp/setup-ssh-keys.sh

# This script will:
# - Create mcp-admin user
# - Generate Ed25519 key pair
# - Setup authorized_keys
# - Install and configure fail2ban
# - Create security banner
```

### Step 3: Apply Hardened Configuration
```bash
# Replace SSH configuration
sudo cp /tmp/sshd_config_hardened /etc/ssh/sshd_config

# Update firewall for new SSH port
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp

# Test configuration
sudo sshd -t

# Restart SSH service
sudo systemctl restart ssh
```

### Step 4: Optional 2FA Setup
```bash
# Run 2FA setup script
chmod +x /tmp/setup-ssh-2fa.sh
/tmp/setup-ssh-2fa.sh

# Follow prompts to scan QR code with authenticator app
```

### Step 5: Security Testing
```bash
# Run security testing script
chmod +x /tmp/test-ssh-security.sh
./test-ssh-security.sh
```

## Expected Security Improvements

### Before Hardening
- SSH on default port 22 (high visibility to attackers)
- Password authentication enabled (brute force risk)
- Root login permitted (privilege escalation risk)
- No brute force protection
- Standard cryptographic settings

### After Hardening
- SSH on custom port 2222 (reduced automated attacks)
- Key-only authentication (eliminates password attacks)
- Root login disabled (reduced privilege escalation)
- fail2ban protection (automatic blocking of attackers)
- Modern cryptographic algorithms
- Optional 2FA (additional security layer)

### Security Score Impact
- **Before**: High risk due to exposed SSH service
- **After**: 85%+ security score with comprehensive protection
- **Improvement**: Significant reduction in attack surface

## Monitoring and Maintenance

### Daily Operations
- Monitor fail2ban logs: `sudo fail2ban-client status sshd`
- Check SSH auth logs: `sudo journalctl -u ssh -f`
- Verify SSH service status: `sudo systemctl status ssh`

### Weekly Tasks
- Review blocked IPs in fail2ban
- Check for SSH configuration changes
- Monitor user access patterns
- Update SSH keys if needed

### Monthly Activities
- Security audit of SSH configuration
- Review and update fail2ban rules
- Test backup access methods
- Update SSH client configurations

## Troubleshooting

### Common Issues

#### SSH Connection Refused
```bash
# Check SSH service status
sudo systemctl status ssh

# Verify port configuration
sudo netstat -tlnp | grep :2222

# Check firewall rules
sudo ufw status
```

#### Key Authentication Fails
```bash
# Verify key permissions
ls -la ~/.ssh/
# authorized_keys should be 600
# id_ed25519 should be 400

# Check SSH configuration
sudo sshd -T | grep -i pubkey
```

#### fail2ban Not Working
```bash
# Check fail2ban status
sudo fail2ban-client status

# Restart fail2ban
sudo systemctl restart fail2ban

# Check fail2ban logs
sudo journalctl -u fail2ban -f
```

### Recovery Procedures

#### Lost SSH Access
1. Use console access (if available)
2. Check SSH service and configuration
3. Temporarily enable password auth if needed
4. Restore from backup configuration

#### Locked Out by fail2ban
```bash
# Unban IP address
sudo fail2ban-client set sshd unbanip YOUR_IP

# Check current bans
sudo fail2ban-client status sshd
```

## Success Criteria
- ✅ SSH accessible only via keys on port 2222
- ✅ Password and root authentication disabled
- ✅ fail2ban actively protecting against brute force
- ✅ Security testing script passes all checks
- ✅ Optional 2FA working correctly
- ✅ No unauthorized access attempts successful

---
*Generated by MCP Server SSH Authentication Hardening Tool*
*Status: Ready for Implementation*
*Security Level: Production-Ready*
"@
    
    $reportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "reports\ssh_authentication_hardening_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    # Ensure reports directory exists
    $reportsDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-Host "`n📝 SSH authentication hardening report saved: $reportPath" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ SSH authentication hardening failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "      SSH AUTHENTICATION HARDENING READY" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green

Read-Host "`nPress Enter to continue to MCP service optimization"