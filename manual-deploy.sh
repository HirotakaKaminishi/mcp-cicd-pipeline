#!/bin/bash

# Manual deployment script for MCP server + React app
# This script will be executed on the remote server to fix the deployment

echo "🚀 Starting manual deployment fix..."

# Navigate to deployment directory
cd /root/mcp_containers

# Stop any existing services
docker compose down 2>/dev/null || echo "No existing services to stop"

# Create new docker-compose.yml
cat > docker-compose-new.yml << 'EOF'
version: '3.8'

services:
  # React Application with Nginx
  react-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: react-nginx-app
    ports:
      - "80:80"
    environment:
      - NODE_ENV=production
      - REACT_APP_MCP_SERVER_URL=http://192.168.111.200:8080
    depends_on:
      - mcp-server
    networks:
      - mcp-network
    restart: unless-stopped
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

  # MCP Server API
  mcp-server:
    build:
      context: ./mcp-server
      dockerfile: Dockerfile
    container_name: mcp-api-server
    ports:
      - "8080:8080"
    environment:
      - PYTHONUNBUFFERED=1
      - FLASK_ENV=production
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - mcp-data:/root/mcp_project
      - mcp-containers:/root/mcp_containers
    networks:
      - mcp-network
    restart: unless-stopped
    privileged: true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # Monitoring (Optional)
  portainer:
    image: portainer/portainer-ce:latest
    container_name: mcp-portainer
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer-data:/data
    networks:
      - mcp-network
    restart: unless-stopped

networks:
  mcp-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  mcp-data:
    driver: local
  mcp-containers:
    driver: local
  portainer-data:
    driver: local
EOF

# Create mcp-server directory structure
mkdir -p mcp-server

# Create MCP server Flask application
cat > mcp-server/app.py << 'EOF'
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import subprocess
import json
import shutil
import psutil
import docker
from datetime import datetime

app = Flask(__name__)
CORS(app)

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "MCP Server API",
        "version": "1.0.0"
    })

@app.route('/api/system/info', methods=['GET'])
def get_system_info():
    try:
        return jsonify({
            "cpu_count": psutil.cpu_count(),
            "memory": dict(psutil.virtual_memory()._asdict()),
            "disk": dict(psutil.disk_usage('/').asdict()),
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/system/execute', methods=['POST'])
def execute_command():
    try:
        data = request.json
        command = data.get('command', '')
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return jsonify({
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/file/read', methods=['POST'])
def read_file():
    try:
        data = request.json
        file_path = data.get('path', '')
        with open(file_path, 'r') as f:
            content = f.read()
        return jsonify({"content": content, "path": file_path})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/file/write', methods=['POST'])
def write_file():
    try:
        data = request.json
        file_path = data.get('path', '')
        content = data.get('content', '')
        with open(file_path, 'w') as f:
            f.write(content)
        return jsonify({"message": "File written successfully", "path": file_path})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/file/list', methods=['POST'])
def list_files():
    try:
        data = request.json
        dir_path = data.get('path', '.')
        files = []
        for item in os.listdir(dir_path):
            item_path = os.path.join(dir_path, item)
            files.append({
                "name": item,
                "path": item_path,
                "is_directory": os.path.isdir(item_path)
            })
        return jsonify({"files": files, "path": dir_path})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/docker/containers', methods=['GET'])
def list_containers():
    try:
        client = docker.from_env()
        containers = []
        for container in client.containers.list(all=True):
            containers.append({
                "id": container.id,
                "name": container.name,
                "status": container.status,
                "image": container.image.tags[0] if container.image.tags else "unknown"
            })
        return jsonify({"containers": containers})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/process/list', methods=['GET'])
def list_processes():
    try:
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
            processes.append(proc.info)
        return jsonify({"processes": processes[:50]})  # Limit to first 50
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

echo "🎉 Manual deployment configuration created successfully!"
echo "📝 Next steps:"
echo "1. Review the configuration files"
echo "2. Run 'docker compose -f docker-compose-new.yml up -d --build' to deploy"
echo "3. Test the endpoints"