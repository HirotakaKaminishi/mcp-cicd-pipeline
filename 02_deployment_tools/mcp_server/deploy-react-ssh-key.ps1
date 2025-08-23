# PowerShell deployment script for React app to MCP Server using SSH key
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting deployment to MCP Server with SSH key..." -ForegroundColor Green

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$mcpServer = "192.168.111.200"
$sshKey = "C:\Users\hirotaka\Documents\work\id_rsa_centos"  # CentOS用のSSH秘密鍵
$appName = "mcp-react-app"
$releaseDir = "/root/mcp_react/releases/$timestamp"

Write-Host "📦 Building React application..." -ForegroundColor Yellow
Set-Location "sample-project-react"
npm run build

Write-Host "📤 Transferring files to MCP Server using SSH key..." -ForegroundColor Yellow

# Create release directory on MCP server
Write-Host "Creating release directory: $releaseDir"
ssh -i $sshKey -o StrictHostKeyChecking=no root@$mcpServer "mkdir -p $releaseDir"

# Copy dist files to MCP server
Write-Host "Copying build files..."
scp -i $sshKey -o StrictHostKeyChecking=no -r dist/* root@${mcpServer}:${releaseDir}/

# Create Nginx configuration
$nginxConfig = @"
server {
    listen 3000;
    server_name _;
    
    root $releaseDir;
    index index.html;
    
    location / {
        try_files `$uri `$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_cache_bypass `$http_upgrade;
    }
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
"@

Write-Host "🔧 Configuring Nginx..." -ForegroundColor Yellow
$nginxConfig | ssh -i $sshKey -o StrictHostKeyChecking=no root@$mcpServer "cat > /etc/nginx/sites-available/mcp-react-app"

# Deploy on MCP server
Write-Host "🚀 Deploying application..." -ForegroundColor Yellow
ssh -i $sshKey -o StrictHostKeyChecking=no root@$mcpServer @"
    # Enable site
    ln -sf /etc/nginx/sites-available/mcp-react-app /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    nginx -t
    
    # Reload nginx
    systemctl reload nginx
    
    # Create symlink to current release
    ln -sfn $releaseDir /root/mcp_react/current
    
    # Clean up old releases (keep last 5)
    cd /root/mcp_react/releases
    ls -1t 2>/dev/null | tail -n +6 | xargs -r rm -rf
    
    echo '✅ Deployment completed!'
    echo '📊 Release info:'
    ls -la /root/mcp_react/current
"@

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "🌐 Application available at: http://$mcpServer`:3000" -ForegroundColor Cyan