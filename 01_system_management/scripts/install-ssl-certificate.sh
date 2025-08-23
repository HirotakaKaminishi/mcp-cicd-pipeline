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
sudo certbot certonly --standalone --preferred-challenges http -d 192.168.111.200

# Copy the SSL nginx configuration
echo "Setting up nginx SSL configuration..."
sudo cp /path/to/nginx-ssl-config.conf /etc/nginx/sites-available/mcp-server-ssl
sudo ln -sf /etc/nginx/sites-available/mcp-server-ssl /etc/nginx/sites-enabled/

# Remove default nginx config if exists
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "Testing nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "笨・nginx configuration is valid"
    
    # Start and enable nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    echo "笨・SSL certificate installed successfully!"
    echo "笨・nginx configured with SSL"
    echo "笨・HTTPS is now available"
    
    # Set up automatic renewal
    echo "Setting up automatic certificate renewal..."
    echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
    
    echo "笨・Automatic renewal configured"
    
else
    echo "笶・nginx configuration test failed"
    echo "Please check the configuration and try again"
    exit 1
fi

# Display SSL certificate information
echo ""
echo "SSL Certificate Information:"
sudo certbot certificates

echo ""
echo "脂 SSL implementation completed successfully!"
echo "Your MCP server is now accessible via HTTPS"
echo "Test URL: https://192.168.111.200"
