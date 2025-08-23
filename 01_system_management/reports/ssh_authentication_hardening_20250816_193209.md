# SSH Authentication Hardening for MCP Server

## Implementation Date
2025-08-16 19:32:09

## Target Server
- **IP Address**: 192.168.111.200
- **SSH Hardening Level**: Production-grade with optional 2FA
- **Security Enhancement**: Multi-layer SSH protection

## Generated Configurations and Scripts

### 1. Hardened SSH Configuration
- **File**: sshd_config_hardened
- **Location**: C:\Users\hirotaka\Documents\work\01_system_management\configs\sshd_config_hardened
- **Features**: Key-only auth, custom port, strong crypto, connection limits

### 2. SSH Key Setup Script
- **File**: setup-ssh-keys.sh
- **Location**: C:\Users\hirotaka\Documents\work\01_system_management\scripts\setup-ssh-keys.sh
- **Purpose**: Automated SSH key generation and user setup

### 3. Two-Factor Authentication Script
- **File**: setup-ssh-2fa.sh
- **Location**: C:\Users\hirotaka\Documents\work\01_system_management\scripts\setup-ssh-2fa.sh
- **Purpose**: TOTP-based 2FA implementation

### 4. Security Testing Script
- **File**: test-ssh-security.sh
- **Location**: C:\Users\hirotaka\Documents\work\01_system_management\scripts\test-ssh-security.sh
- **Purpose**: Comprehensive SSH security validation

## Security Measures Implemented

### Authentication Hardening
- **Change Default Port**: Move SSH from port 22 to custom port
  - Priority: High
  - Security Level: Medium
  - Implementation Effort: Low
 - **Connection Limits**: Limit concurrent SSH connections
  - Priority: Low
  - Security Level: Low
  - Implementation Effort: Low
 - **Two-Factor Authentication**: Add TOTP-based 2FA for additional security
  - Priority: Medium
  - Security Level: Very High
  - Implementation Effort: High
 - **Fail2ban Implementation**: Automatic blocking of brute force attempts
  - Priority: High
  - Security Level: High
  - Implementation Effort: Medium
 - **Disable Root Login**: Prevent direct root access via SSH
  - Priority: Critical
  - Security Level: High
  - Implementation Effort: Low
 - **SSH Key Restrictions**: Limit SSH key usage and permissions
  - Priority: Medium
  - Security Level: Medium
  - Implementation Effort: Medium
 - **Key-based Authentication**: Replace password authentication with SSH keys
  - Priority: Critical
  - Security Level: High
  - Implementation Effort: Medium


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
`ash
# Backup current SSH configuration
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Copy scripts to server
scp setup-ssh-keys.sh user@192.168.111.200:/tmp/
scp sshd_config_hardened user@192.168.111.200:/tmp/
scp setup-ssh-2fa.sh user@192.168.111.200:/tmp/
scp test-ssh-security.sh user@192.168.111.200:/tmp/
`

### Step 2: SSH Key Setup
`ash
# On the MCP server
chmod +x /tmp/setup-ssh-keys.sh
sudo /tmp/setup-ssh-keys.sh

# This script will:
# - Create mcp-admin user
# - Generate Ed25519 key pair
# - Setup authorized_keys
# - Install and configure fail2ban
# - Create security banner
`

### Step 3: Apply Hardened Configuration
`ash
# Replace SSH configuration
sudo cp /tmp/sshd_config_hardened /etc/ssh/sshd_config

# Update firewall for new SSH port
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp

# Test configuration
sudo sshd -t

# Restart SSH service
sudo systemctl restart ssh
`

### Step 4: Optional 2FA Setup
`ash
# Run 2FA setup script
chmod +x /tmp/setup-ssh-2fa.sh
/tmp/setup-ssh-2fa.sh

# Follow prompts to scan QR code with authenticator app
`

### Step 5: Security Testing
`ash
# Run security testing script
chmod +x /tmp/test-ssh-security.sh
./test-ssh-security.sh
`

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
- Monitor fail2ban logs: sudo fail2ban-client status sshd
- Check SSH auth logs: sudo journalctl -u ssh -f
- Verify SSH service status: sudo systemctl status ssh

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
`ash
# Check SSH service status
sudo systemctl status ssh

# Verify port configuration
sudo netstat -tlnp | grep :2222

# Check firewall rules
sudo ufw status
`

#### Key Authentication Fails
`ash
# Verify key permissions
ls -la ~/.ssh/
# authorized_keys should be 600
# id_ed25519 should be 400

# Check SSH configuration
sudo sshd -T | grep -i pubkey
`

#### fail2ban Not Working
`ash
# Check fail2ban status
sudo fail2ban-client status

# Restart fail2ban
sudo systemctl restart fail2ban

# Check fail2ban logs
sudo journalctl -u fail2ban -f
`

### Recovery Procedures

#### Lost SSH Access
1. Use console access (if available)
2. Check SSH service and configuration
3. Temporarily enable password auth if needed
4. Restore from backup configuration

#### Locked Out by fail2ban
`ash
# Unban IP address
sudo fail2ban-client set sshd unbanip YOUR_IP

# Check current bans
sudo fail2ban-client status sshd
`

## Success Criteria
- 笨・SSH accessible only via keys on port 2222
- 笨・Password and root authentication disabled
- 笨・fail2ban actively protecting against brute force
- 笨・Security testing script passes all checks
- 笨・Optional 2FA working correctly
- 笨・No unauthorized access attempts successful

---
*Generated by MCP Server SSH Authentication Hardening Tool*
*Status: Ready for Implementation*
*Security Level: Production-Ready*
