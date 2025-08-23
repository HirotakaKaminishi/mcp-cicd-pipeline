#!/bin/bash
# SSH Key Generation and Setup Script

echo "==================================="
echo "    SSH Key Generation & Setup"
echo "==================================="

# Configuration
SSH_USER="mcp-admin"
KEY_TYPE="ed25519"
KEY_COMMENT="MCP-Server-Admin-Key-$(date +%Y%m%d)"
BACKUP_DIR="/home/$SSH_USER/.ssh/backup"

echo "Setting up SSH key authentication for user: $SSH_USER"

# Create SSH user if doesn't exist
if ! id "$SSH_USER" &>/dev/null; then
    echo "Creating user: $SSH_USER"
    sudo useradd -m -s /bin/bash "$SSH_USER"
    sudo usermod -aG sudo "$SSH_USER"
    echo "笨・User $SSH_USER created with sudo privileges"
else
    echo "笨・User $SSH_USER already exists"
fi

# Switch to the SSH user for key operations
sudo -u "$SSH_USER" bash << 'EOF'
# Create .ssh directory with correct permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Backup existing keys if any
if [ -f ~/.ssh/authorized_keys ]; then
    echo "Backing up existing authorized_keys..."
    mkdir -p ~/.ssh/backup
    cp ~/.ssh/authorized_keys ~/.ssh/backup/authorized_keys.$(date +%Y%m%d_%H%M%S)
fi

# Generate new SSH key pair
echo "Generating new Ed25519 SSH key pair..."
ssh-keygen -t ed25519 -C "MCP-Server-Admin-Key-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519 -N ""

if [ $? -eq 0 ]; then
    echo "笨・SSH key pair generated successfully"
    
    # Add public key to authorized_keys
    cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    chmod 400 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    
    echo "笨・SSH key added to authorized_keys"
    
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
    echo "笞・・ IMPORTANT: Keep the private key secure!"
    
else
    echo "笶・Failed to generate SSH key pair"
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

echo "笨・SSH banner created"

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

echo "笨・fail2ban configured for SSH protection"

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
echo "ssh -i path/to/private/key -p 2222 $SSH_USER@192.168.111.200"
