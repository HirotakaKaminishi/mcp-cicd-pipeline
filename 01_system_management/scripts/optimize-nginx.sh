#!/bin/bash
# nginx Optimization Deployment Script

echo "==================================="
echo "    nginx Optimization Deployment"
echo "==================================="

# Configuration
NGINX_CONF_BACKUP="/etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)"
VHOST_BACKUP="/etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)"

echo "Deploying nginx optimizations..."

# Create cache directories
echo "Creating cache directories..."
sudo mkdir -p /var/cache/nginx/fastcgi
sudo mkdir -p /var/cache/nginx/proxy
sudo mkdir -p /var/cache/nginx/proxy_temp
sudo chown -R www-data:www-data /var/cache/nginx/
echo "笨・Cache directories created"

# Backup current configuration
echo "Backing up current nginx configuration..."
sudo cp /etc/nginx/nginx.conf "$NGINX_CONF_BACKUP"
echo "笨・nginx.conf backed up to $NGINX_CONF_BACKUP"

if [ -f "/etc/nginx/sites-available/default" ]; then
    sudo cp /etc/nginx/sites-available/default "$VHOST_BACKUP"
    echo "笨・Default vhost backed up to $VHOST_BACKUP"
fi

# Deploy optimized nginx configuration
if [ -f "/tmp/nginx_optimized.conf" ]; then
    echo "Deploying optimized nginx.conf..."
    sudo cp /tmp/nginx_optimized.conf /etc/nginx/nginx.conf
    echo "笨・Optimized nginx.conf deployed"
else
    echo "笶・Optimized nginx.conf not found at /tmp/"
    exit 1
fi

# Deploy optimized virtual host
if [ -f "/tmp/mcp-optimized-vhost.conf" ]; then
    echo "Deploying optimized virtual host..."
    sudo cp /tmp/mcp-optimized-vhost.conf /etc/nginx/sites-available/mcp-optimized
    
    # Enable the new site
    sudo ln -sf /etc/nginx/sites-available/mcp-optimized /etc/nginx/sites-enabled/
    
    # Disable default site
    sudo rm -f /etc/nginx/sites-enabled/default
    
    echo "笨・Optimized virtual host deployed and enabled"
else
    echo "笶・Optimized virtual host not found at /tmp/"
    exit 1
fi

# Create web root directories
echo "Creating web root directories..."
sudo mkdir -p /var/www/mcp
sudo mkdir -p /var/www/mcp-dev
sudo chown -R www-data:www-data /var/www/mcp*

# Create basic index file
sudo tee /var/www/mcp/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>MCP Server</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>MCP Server</h1>
    <p>Model Context Protocol Server is running.</p>
    <ul>
        <li><a href="/health">Health Check</a></li>
        <li><a href="/api/info">API Information</a></li>
        <li><a href="/nginx-health">nginx Health</a></li>
    </ul>
</body>
</html>
EOF

echo "笨・Web root directories and index file created"

# Test nginx configuration
echo "Testing nginx configuration..."
if sudo nginx -t; then
    echo "笨・nginx configuration test passed"
    
    # Reload nginx
    echo "Reloading nginx..."
    sudo systemctl reload nginx
    
    if [ $? -eq 0 ]; then
        echo "笨・nginx reloaded successfully"
    else
        echo "笶・nginx reload failed"
        echo "Restoring backup configuration..."
        sudo cp "$NGINX_CONF_BACKUP" /etc/nginx/nginx.conf
        sudo nginx -t && sudo systemctl reload nginx
        exit 1
    fi
else
    echo "笶・nginx configuration test failed"
    echo "Restoring backup configuration..."
    sudo cp "$NGINX_CONF_BACKUP" /etc/nginx/nginx.conf
    exit 1
fi

# Install nginx monitoring tools
echo "Installing nginx monitoring tools..."
sudo apt update
sudo apt install nginx-extras -y  # For additional modules

# Configure log rotation
echo "Configuring log rotation..."
sudo tee /etc/logrotate.d/nginx-optimized > /dev/null << 'EOF'
/var/log/nginx/mcp-*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 www-data adm
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 cat /var/run/nginx.pid
        fi
    endscript
}
EOF

echo "笨・Log rotation configured"

# Performance tuning for system
echo "Applying system-level optimizations..."

# Increase file descriptor limits
echo "www-data soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "www-data hard nofile 65535" | sudo tee -a /etc/security/limits.conf

# TCP optimization
sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'

# nginx optimization
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
EOF

sudo sysctl -p

echo "笨・System-level optimizations applied"

# Create monitoring script
sudo tee /usr/local/bin/nginx-monitor.sh > /dev/null << 'EOF'
#!/bin/bash
# nginx Monitoring Script

echo "nginx Status Report - $(date)"
echo "=================================="

# Basic status
echo "Service Status: $(systemctl is-active nginx)"
echo "Configuration Test: $(nginx -t 2>&1 | grep -q 'syntax is ok' && echo 'OK' || echo 'FAILED')"

# Connection stats
if command -v ss &> /dev/null; then
    echo "Active Connections: $(ss -tuln | grep ':80\|:443' | wc -l)"
fi

# Memory usage
echo "Memory Usage: $(ps aux | grep nginx | grep -v grep | awk '{sum += $6} END {print sum/1024 " MB"}')"

# Recent errors
echo ""
echo "Recent Errors (last 10):"
tail -10 /var/log/nginx/error.log | tail -5

# Cache status
echo ""
echo "Cache Usage:"
du -sh /var/cache/nginx/* 2>/dev/null | head -5
EOF

sudo chmod +x /usr/local/bin/nginx-monitor.sh

echo "笨・Monitoring script created: /usr/local/bin/nginx-monitor.sh"

# Test the optimization
echo ""
echo "Testing optimized configuration..."

# Test basic connectivity
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200\|301\|302"; then
    echo "笨・HTTP connectivity test passed"
else
    echo "笞・・ HTTP connectivity test failed"
fi

# Test nginx health endpoint
if curl -s http://localhost/nginx-health | grep -q "healthy"; then
    echo "笨・nginx health endpoint working"
else
    echo "笞・・ nginx health endpoint not responding"
fi

echo ""
echo "==================================="
echo "    nginx Optimization Complete"
echo "==================================="
echo ""
echo "Configuration Summary:"
echo "窶｢ Main config: /etc/nginx/nginx.conf (optimized)"
echo "窶｢ Virtual host: /etc/nginx/sites-available/mcp-optimized"
echo "窶｢ Cache directory: /var/cache/nginx/"
echo "窶｢ Web root: /var/www/mcp/"
echo "窶｢ Backup: $NGINX_CONF_BACKUP"
echo ""
echo "Monitoring:"
echo "窶｢ Run: /usr/local/bin/nginx-monitor.sh"
echo "窶｢ Logs: /var/log/nginx/mcp-*.log"
echo "窶｢ Test: nginx -t"
echo ""
echo "Performance Features Enabled:"
echo "窶｢ HTTP/2 support"
echo "窶｢ gzip compression"
echo "窶｢ Proxy caching"
echo "窶｢ Static file optimization"
echo "窶｢ Rate limiting"
echo "窶｢ Security headers"
echo ""
echo "Next steps:"
echo "1. Configure SSL certificates"
echo "2. Test application functionality"
echo "3. Monitor performance metrics"
echo "4. Fine-tune based on usage patterns"
