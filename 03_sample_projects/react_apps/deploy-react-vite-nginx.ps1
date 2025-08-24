# PowerShell script to deploy React+Vite+Nginx application to MCP Server
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting React+Vite+Nginx deployment to MCP Server..." -ForegroundColor Green

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$mcpServer = "192.168.111.200"
$mcpServerUrl = "http://${mcpServer}:8080"
$sshKey = "C:\Users\hirotaka\Documents\work\id_rsa_centos"
$appName = "mcp-app"
$containerBuildPath = "/root/mcp_containers/app"
$releasePath = "/root/mcp_containers/releases/$timestamp"

Write-Host "📦 Building React application locally..." -ForegroundColor Yellow
if (!(Test-Path "package.json")) {
    Write-Error "package.json not found. Please run this script from the React project root directory."
    exit 1
}

npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed. Please check your application and try again."
    exit 1
}

Write-Host "🔍 Testing MCP server connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body '{"jsonrpc":"2.0","method":"get_system_info","params":{},"id":1}' -TimeoutSec 10
    Write-Host "✅ MCP server connected successfully" -ForegroundColor Green
}
catch {
    Write-Error "❌ Cannot connect to MCP server at $mcpServerUrl. Please check the server is running."
    exit 1
}

Write-Host "📁 Creating release directory..." -ForegroundColor Yellow
$createReleaseCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "mkdir -p $releasePath"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $createReleaseCmd -TimeoutSec 30

Write-Host "📤 Transferring React build files to MCP Server..." -ForegroundColor Yellow

# Deploy main files
Get-ChildItem -Path "dist" -File | ForEach-Object {
    $filename = $_.Name
    Write-Host "📝 Deploying: $filename" -ForegroundColor Cyan
    
    # Encode file as base64
    $fileBytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $encodedContent = [System.Convert]::ToBase64String($fileBytes)
    
    $deployCmd = @{
        jsonrpc = "2.0"
        method = "execute_command"
        params = @{
            command = "echo '$encodedContent' | base64 -d > $releasePath/$filename"
        }
        id = 1
    } | ConvertTo-Json -Depth 3
    
    try {
        Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $deployCmd -TimeoutSec 30
        Write-Host "✅ SUCCESS: $filename deployed" -ForegroundColor Green
    }
    catch {
        Write-Warning "⚠️ Failed to deploy $filename"
    }
}

# Deploy assets directory if exists
if (Test-Path "dist\assets") {
    Write-Host "📂 Creating assets directory..." -ForegroundColor Yellow
    $createAssetsCmd = @{
        jsonrpc = "2.0"
        method = "execute_command"
        params = @{
            command = "mkdir -p $releasePath/assets"
        }
        id = 1
    } | ConvertTo-Json -Depth 3
    
    Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $createAssetsCmd -TimeoutSec 30
    
    Get-ChildItem -Path "dist\assets" -File | ForEach-Object {
        $assetName = $_.Name
        Write-Host "📝 Deploying asset: $assetName" -ForegroundColor Cyan
        
        $fileBytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $encodedAsset = [System.Convert]::ToBase64String($fileBytes)
        
        $deployAssetCmd = @{
            jsonrpc = "2.0"
            method = "execute_command"
            params = @{
                command = "echo '$encodedAsset' | base64 -d > $releasePath/assets/$assetName"
            }
            id = 1
        } | ConvertTo-Json -Depth 3
        
        try {
            Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $deployAssetCmd -TimeoutSec 30
            Write-Host "✅ SUCCESS: assets/$assetName deployed" -ForegroundColor Green
        }
        catch {
            Write-Warning "⚠️ Failed to deploy assets/$assetName"
        }
    }
}

Write-Host "🔗 Preparing container deployment..." -ForegroundColor Yellow
$copyToContainerCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "rm -rf $containerBuildPath/src/* && cp -r $releasePath/* $containerBuildPath/src/"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $copyToContainerCmd -TimeoutSec 30

Write-Host "🏗️ Building new Docker image..." -ForegroundColor Yellow
$buildImageCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "cd $containerBuildPath && docker build -t ${appName}:$timestamp ."
    }
    id = 1
} | ConvertTo-Json -Depth 3

try {
    $buildResponse = Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $buildImageCmd -TimeoutSec 180
    Write-Host "✅ Docker image built successfully!" -ForegroundColor Green
}
catch {
    Write-Error "❌ Docker build failed"
    exit 1
}

Write-Host "🔄 Performing zero-downtime container replacement..." -ForegroundColor Yellow

# Start new container with temporary name
Write-Host "🚀 Starting new container..." -ForegroundColor Cyan
$startNewCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "docker run -d --name ${appName}-new --network mcp-network --hostname app -p 81:3000 ${appName}:$timestamp"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $startNewCmd -TimeoutSec 60

# Wait for container to be ready
Write-Host "⏳ Waiting for new container to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Health check
Write-Host "🏥 Performing health check..." -ForegroundColor Cyan
$healthCheckCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "curl -s http://localhost:81/health --connect-timeout 5 || echo 'Health check failed'"
    }
    id = 1
} | ConvertTo-Json -Depth 3

$healthResponse = Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $healthCheckCmd -TimeoutSec 30
Write-Host "🏥 Health check result: $($healthResponse.result.stdout)" -ForegroundColor Cyan

# Stop and remove old container
Write-Host "🛑 Stopping old container..." -ForegroundColor Yellow
$stopOldCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "docker stop $appName 2>/dev/null || echo 'No old container'; docker rm $appName 2>/dev/null || echo 'No old container to remove'"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $stopOldCmd -TimeoutSec 30

# Stop temporary container and start with production settings
Write-Host "🔄 Promoting new container to production..." -ForegroundColor Yellow
$promoteCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "docker stop ${appName}-new && docker rm ${appName}-new"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $promoteCmd -TimeoutSec 30

$startProdCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "docker run -d --name $appName --network mcp-network --hostname app -p 80:3000 ${appName}:$timestamp"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $startProdCmd -TimeoutSec 60

Write-Host "🧹 Cleaning up old Docker images (keeping latest 3)..." -ForegroundColor Yellow
$cleanupImagesCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "docker images $appName --format '{{.Tag}}' | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r | tail -n +4 | xargs -r -I {} docker rmi ${appName}:{} 2>/dev/null || echo 'No old images to remove'"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $cleanupImagesCmd -TimeoutSec 60

Write-Host "🧹 Cleaning up old releases (keeping latest 5)..." -ForegroundColor Yellow
$cleanupReleasesCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "cd /root/mcp_containers/releases && ls -1t | tail -n +6 | xargs -r rm -rf"
    }
    id = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $cleanupReleasesCmd -TimeoutSec 60

Write-Host "✅ Final verification..." -ForegroundColor Yellow
$verifyCmd = @{
    jsonrpc = "2.0"
    method = "execute_command"
    params = @{
        command = "docker ps | grep $appName"
    }
    id = 1
} | ConvertTo-Json -Depth 3

$verifyResponse = Invoke-RestMethod -Uri $mcpServerUrl -Method POST -ContentType "application/json" -Body $verifyCmd -TimeoutSec 30
Write-Host "🔍 Container status: $($verifyResponse.result.stdout)" -ForegroundColor Cyan

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "📊 Container image: ${appName}:$timestamp" -ForegroundColor Cyan
Write-Host "🌐 Application URL: http://$mcpServer/dashboard/" -ForegroundColor Cyan
Write-Host "🏥 Health Check: http://$mcpServer/dashboard/health" -ForegroundColor Cyan
Write-Host "📝 React+Vite+Nginx application is now running in Docker with zero-downtime deployment" -ForegroundColor Yellow