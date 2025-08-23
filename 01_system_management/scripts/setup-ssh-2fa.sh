#!/bin/bash
# Two-Factor Authentication Setup for SSH

echo "==================================="
echo "  Two-Factor Authentication Setup"
echo "==================================="

# Install Google Authenticator PAM module
echo "Installing Google Authenticator PAM module..."
sudo apt update
sudo apt install libpam-google-authenticator -y

if [ $? -eq 0 ]; then
    echo "笨・Google Authenticator installed successfully"
else
    echo "笶・Failed to install Google Authenticator"
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

echo "笨・SSH configured for 2FA"

# Setup 2FA for user
echo ""
echo "Setting up 2FA for user: $USER"
echo "You will be prompted to scan a QR code with your authenticator app"
echo ""

# Run Google Authenticator setup
google-authenticator -t -d -f -r 3 -R 30 -W

if [ $? -eq 0 ]; then
    echo "笨・2FA setup completed for user: $USER"
    
    # Restart SSH service
    echo "Restarting SSH service..."
    sudo systemctl restart ssh
    
    if [ $? -eq 0 ]; then
        echo "笨・SSH service restarted successfully"
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
        echo "笶・Failed to restart SSH service"
        echo "Please check SSH configuration and restart manually"
    fi
else
    echo "笶・2FA setup failed"
    exit 1
fi
