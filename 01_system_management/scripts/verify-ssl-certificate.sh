#!/bin/bash
# SSL Certificate Verification Script

echo "==================================="
echo "    SSL Certificate Verification"
echo "==================================="

# Check if certificates exist
echo "Checking certificate files..."
if [ -f "/etc/letsencrypt/live/192.168.111.200/fullchain.pem" ]; then
    echo "笨・SSL certificate found"
    
    # Display certificate details
    echo ""
    echo "Certificate details:"
    sudo openssl x509 -in /etc/letsencrypt/live/192.168.111.200/fullchain.pem -text -noout | grep -E "Subject:|Issuer:|Not Before:|Not After:"
    
else
    echo "笶・SSL certificate not found"
    echo "Please run the SSL installation script first"
    exit 1
fi

# Check nginx configuration
echo ""
echo "Checking nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "笨・nginx configuration is valid"
else
    echo "笶・nginx configuration has errors"
    exit 1
fi

# Check nginx status
echo ""
echo "Checking nginx service status..."
sudo systemctl status nginx --no-pager

# Test HTTPS connectivity
echo ""
echo "Testing HTTPS connectivity..."
curl -I https://192.168.111.200 --insecure

# Check SSL certificate from external perspective
echo ""
echo "SSL certificate check from external perspective:"
echo "Run this command from another machine:"
echo "openssl s_client -connect  -servername 192.168.111.200"

echo ""
echo "脂 SSL verification completed!"
