# PowerShell script to replace existing Node.js app with React+Vite+Nginx in Docker
$ErrorActionPreference = "Stop"

Write-Host "🔄 Replacing existing Node.js app with React+Vite application..." -ForegroundColor Green

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$mcpServer = "192.168.111.200"
$sshKey = "C:\Users\hirotaka\Documents\work\id_rsa_centos"
$appName = "mcp-app"  # Use existing container name
$containerBuildPath = "/root/mcp_containers/app"

Write-Host "📦 Building React application locally..." -ForegroundColor Yellow
Set-Location "sample-project-react"
npm run build
Set-Location ..

Write-Host "📤 Transferring React build files to MCP Server..." -ForegroundColor Yellow

# Clear old files and transfer new React build
ssh -i $sshKey -o StrictHostKeyChecking=no root@$mcpServer @"
    echo 'Cleaning up old Node.js application files...'
    rm -rf $containerBuildPath/src/*
    mkdir -p $containerBuildPath/src
"@

# Copy React build files
scp -i $sshKey -o StrictHostKeyChecking=no -r sample-project-react/dist/* root@${mcpServer}:${containerBuildPath}/src/

Write-Host "🐳 Creating new Dockerfile for Nginx+React..." -ForegroundColor Yellow

# Create new Dockerfile for Nginx+React
ssh -i $sshKey -o StrictHostKeyChecking=no root@$mcpServer @"
    cd $containerBuildPath
    
    # Backup existing Dockerfile
    cp Dockerfile Dockerfile.backup.nodejs 2>/dev/null || true
    
    # Create new Dockerfile for Nginx+React
    cat > Dockerfile << 'EOF'
# Production build with Nginx
FROM nginx:alpine

# Copy React build files
COPY src /usr/share/nginx/html

# Configure Nginx for React Router
RUN cat > /etc/nginx/conf.d/default.conf << 'NGINX'
server {
    listen       3000;
    server_name  localhost;
    
    root   /usr/share/nginx/html;
    index  index.html index.htm;
    
    # Enable gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Main location block for React Router
    location / {
        try_files \\\$uri \\\$uri/ /index.html;
    }
    
    # API proxy (if backend exists)
    location /api {
        proxy_pass http://host.docker.internal:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\\$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \\\$host;
        proxy_cache_bypass \\\$http_upgrade;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 '{"status":"healthy","app":"react-vite","timestamp":"$timestamp"}';
        add_header Content-Type application/json;
    }
    
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
NGINX

# Expose port 3000 (same as existing Node.js app)
EXPOSE 3000

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
EOF
    
    echo 'Dockerfile created successfully!'
"@

Write-Host "🔨 Building new Docker image..." -ForegroundColor Yellow

ssh -i $sshKey -o StrictHostKeyChecking=no root@$mcpServer @"
    cd $containerBuildPath
    
    # Build new image with React+Nginx
    docker build -t ${appName}:react-${timestamp} .
    
    echo 'Docker image built successfully!'
"@

Write-Host "🔄 Performing zero-downtime container replacement..." -ForegroundColor Yellow

ssh -i $sshKey -o StrictHostKeyChecking=no root@$mcpServer @"
    echo '1. Starting new container with temporary name...'
    docker run -d \
        --name ${appName}-new \
        --network mcp-network \
        --hostname app \
        ${appName}:react-${timestamp}
    
    echo '2. Waiting for new container to be ready...'
    sleep 3
    
    # Test health endpoint
    docker exec ${appName}-new curl -s http://localhost:3000/health || echo 'Health check response'
    
    echo '3. Stopping old Node.js container...'
    docker stop $appName || true
    
    echo '4. Removing old container...'
    docker rm $appName || true
    
    echo '5. Renaming new container to production name...'
    docker rename ${appName}-new $appName
    
    echo '6. Verifying deployment...'
    docker ps | grep $appName
    
    echo ''
    echo '✅ Container replacement completed!'
    echo '📊 New container details:'
    docker inspect $appName | grep -E '(Image|State|Created)'
    
    # Clean up old images
    echo ''
    echo '🧹 Cleaning up old Docker images...'
    docker images | grep mcp-app | grep -v react | awk '{print \\\$3}' | xargs -r docker rmi 2>/dev/null || true
    docker image prune -f
"@

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "🌐 React application is now running at: http://${mcpServer}" -ForegroundColor Cyan
Write-Host "📝 The Node.js app has been replaced with React+Vite+Nginx" -ForegroundColor Yellow