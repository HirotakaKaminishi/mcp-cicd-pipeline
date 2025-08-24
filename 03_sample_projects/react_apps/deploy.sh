#!/bin/bash

# Deploy script for React application to MCP Server
set -e

echo "🚀 Starting deployment to MCP Server..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
APP_NAME="mcp-react-app"
IMAGE_TAG="$APP_NAME:$TIMESTAMP"
CONTAINER_NAME="mcp-react-app"
MCP_SERVER="192.168.111.200"

echo "📦 Building Docker image: $IMAGE_TAG"
docker build -t $IMAGE_TAG .

echo "🏷️ Tagging image for registry..."
docker tag $IMAGE_TAG $MCP_SERVER:5000/$IMAGE_TAG

echo "📤 Pushing to MCP registry..."
docker push $MCP_SERVER:5000/$IMAGE_TAG || {
    echo "⚠️ Registry push failed, deploying locally..."
}

echo "🔄 Deploying to MCP Server..."
ssh root@$MCP_SERVER << EOF
    echo "🛑 Stopping old container..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    
    echo "🚀 Starting new container..."
    docker run -d \
        --name $CONTAINER_NAME \
        --restart unless-stopped \
        -p 3000:80 \
        --network mcp-network \
        $IMAGE_TAG
    
    echo "✅ Container started successfully"
    
    echo "🧹 Cleaning up old images..."
    docker image prune -f
    
    echo "📊 Container status:"
    docker ps | grep $CONTAINER_NAME
EOF

echo "🎉 Deployment completed successfully!"
echo "🌐 Application available at: http://$MCP_SERVER:3000"