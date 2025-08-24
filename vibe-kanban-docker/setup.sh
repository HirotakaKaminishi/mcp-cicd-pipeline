#!/bin/bash
# Vibe-Kanban Docker Setup Script

echo "🚀 Vibe-Kanban Docker Setup"
echo "=========================="

# Build the Docker image
echo "📦 Building vibe-kanban Docker image..."
docker build -t vibe-kanban-complete .

# Start the container using docker-compose
echo "🔧 Starting vibe-kanban container..."
cd ..
docker-compose up -d vibe-kanban

# Wait for container to be healthy
echo "⏳ Waiting for vibe-kanban to be ready..."
sleep 10

# Health check
echo "🏥 Checking health status..."
docker-compose exec vibe-kanban curl -f http://localhost:3000 || {
    echo "❌ Health check failed. Checking logs..."
    docker-compose logs vibe-kanban
    exit 1
}

echo "✅ Vibe-Kanban is running successfully!"
echo "🌐 Access the dashboard at: http://localhost:3001"
echo ""
echo "📊 Container status:"
docker-compose ps vibe-kanban