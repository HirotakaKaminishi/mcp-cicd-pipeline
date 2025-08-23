#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Install Docker and Setup Container-based Deployment Environment
"""

import requests
import json
import time

def execute_mcp_command(command, timeout=300):  # Increased timeout for installations
    """Execute command on MCP server"""
    url = 'http://192.168.111.200:8080'
    payload = {
        'jsonrpc': '2.0',
        'method': 'execute_command',
        'params': {'command': command},
        'id': 1
    }
    try:
        response = requests.post(url, json=payload, timeout=timeout)
        if response.status_code == 200:
            result = response.json()
            if 'result' in result:
                return result['result']
    except Exception as e:
        return {'error': str(e)}
    return {'error': 'Command failed'}

print('Docker Installation and Container Setup for MCP Server')
print('=' * 65)

# 1. Install Docker Engine on CentOS Stream 9
print('\n[1] Installing Docker Engine...')
print('[STEP 1.1] Setting up Docker repository...')

# Remove any existing Docker packages
remove_old = execute_mcp_command('dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine')
print(f'[CLEANUP] Old Docker packages removed: {remove_old.get("returncode", "unknown")}')

# Install required packages
install_utils = execute_mcp_command('dnf install -y dnf-utils')
if install_utils.get('returncode') == 0:
    print('[UTILS] dnf-utils installed successfully')
else:
    print(f'[UTILS] Installation failed: {install_utils.get("stderr", "Unknown error")}')

# Add Docker repository
add_repo = execute_mcp_command('dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo')
if add_repo.get('returncode') == 0:
    print('[REPO] Docker repository added successfully')
else:
    print(f'[REPO] Repository addition failed: {add_repo.get("stderr", "Unknown error")}')

print('\n[STEP 1.2] Installing Docker CE...')
# Install Docker CE
install_docker = execute_mcp_command('dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin')

if install_docker.get('returncode') == 0:
    print('[DOCKER] Docker CE installed successfully')
else:
    print('[DOCKER] Docker installation may have issues')
    if install_docker.get('stderr'):
        print(f'[ERROR] {install_docker["stderr"][:200]}...')

# 2. Start and enable Docker service
print('\n[2] Starting Docker Service...')
start_docker = execute_mcp_command('systemctl start docker')
if start_docker.get('returncode') == 0:
    print('[START] Docker service started')
else:
    print(f'[START] Docker start failed: {start_docker.get("stderr", "Unknown error")}')

enable_docker = execute_mcp_command('systemctl enable docker')
if enable_docker.get('returncode') == 0:
    print('[ENABLE] Docker service enabled for auto-start')
else:
    print(f'[ENABLE] Docker enable failed: {enable_docker.get("stderr", "Unknown error")}')

# Wait for Docker to be ready
print('\n[3] Verifying Docker Installation...')
time.sleep(5)

docker_version = execute_mcp_command('docker --version')
if docker_version.get('stdout'):
    print('[VERSION] Docker version:')
    print(f'  {docker_version["stdout"].strip()}')

docker_info = execute_mcp_command('docker info')
if docker_info.get('stdout'):
    print('[INFO] Docker daemon is running')
    info_lines = docker_info['stdout'].split('\n')
    for line in info_lines[:10]:
        if any(keyword in line.lower() for keyword in ['server version', 'storage driver', 'containers', 'images']):
            print(f'  {line.strip()}')
else:
    print('[INFO] Docker daemon verification failed')

# 3. Test Docker with hello-world
print('\n[4] Testing Docker Installation...')
hello_world = execute_mcp_command('docker run hello-world')
if hello_world.get('stdout') and 'Hello from Docker!' in hello_world['stdout']:
    print('[TEST] ✓ Docker installation test successful')
    print('[TEST] hello-world container ran successfully')
else:
    print('[TEST] Docker test may have failed')
    if hello_world.get('stderr'):
        print(f'[TEST ERROR] {hello_world["stderr"][:200]}')

# 4. Create Docker network for MCP applications
print('\n[5] Setting up Container Network...')
create_network = execute_mcp_command('docker network create mcp-network')
if create_network.get('returncode') == 0:
    print('[NETWORK] mcp-network created successfully')
else:
    print('[NETWORK] Network creation may have failed (might already exist)')

# List networks
list_networks = execute_mcp_command('docker network ls')
if list_networks.get('stdout'):
    print('[NETWORKS] Available Docker networks:')
    for line in list_networks['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('\n' + '=' * 65)
print('CONTAINER DEPLOYMENT ARCHITECTURE DESIGN')
print('=' * 65)

# 5. Create container deployment structure
print('\n[CONTAINER STRUCTURE] Setting up deployment directories...')

# Create container deployment directory
create_dirs = execute_mcp_command('mkdir -p /root/mcp_containers/{app,nginx,database}')
if create_dirs.get('returncode') == 0:
    print('[DIRS] Container directories created')

# Create application Dockerfile
dockerfile_content = '''FROM node:18-alpine

# Set working directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY src/ ./src/

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "src/app.js"]
'''

# Encode Dockerfile content
import base64
encoded_dockerfile = base64.b64encode(dockerfile_content.encode()).decode()

create_dockerfile = execute_mcp_command(f'echo "{encoded_dockerfile}" | base64 -d > /root/mcp_containers/app/Dockerfile')
if create_dockerfile.get('returncode') == 0:
    print('[DOCKERFILE] Application Dockerfile created')

# Create docker-compose.yml
compose_content = '''version: '3.8'

services:
  app:
    build: ./app
    container_name: mcp-app
    networks:
      - mcp-network
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  nginx:
    image: nginx:alpine
    container_name: mcp-nginx
    networks:
      - mcp-network
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app
    restart: unless-stopped

networks:
  mcp-network:
    driver: bridge
'''

encoded_compose = base64.b64encode(compose_content.encode()).decode()
create_compose = execute_mcp_command(f'echo "{encoded_compose}" | base64 -d > /root/mcp_containers/docker-compose.yml')
if create_compose.get('returncode') == 0:
    print('[COMPOSE] docker-compose.yml created')

# Create nginx configuration
nginx_config = '''events {
    worker_connections 1024;
}

http {
    upstream app {
        server mcp-app:3000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /health {
            proxy_pass http://app/health;
            access_log off;
        }
    }
}
'''

encoded_nginx = base64.b64encode(nginx_config.encode()).decode()
create_nginx_dir = execute_mcp_command('mkdir -p /root/mcp_containers/nginx')
create_nginx_config = execute_mcp_command(f'echo "{encoded_nginx}" | base64 -d > /root/mcp_containers/nginx/nginx.conf')
if create_nginx_config.get('returncode') == 0:
    print('[NGINX] Nginx configuration created')

# List created structure
list_structure = execute_mcp_command('find /root/mcp_containers -type f | head -10')
if list_structure.get('stdout'):
    print('\n[STRUCTURE] Created container structure:')
    for line in list_structure['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('\n' + '=' * 65)
print('CONTAINER-BASED CI/CD PIPELINE DESIGN')
print('=' * 65)

print('\n[DEPLOYMENT STRATEGY]')
print('Current: Direct deployment to host')
print('New: Container-based deployment')
print('')
print('Advantages of Container Approach:')
print('  ✓ Environment Isolation')
print('  ✓ Easy Scaling (docker-compose scale app=3)')
print('  ✓ Zero-downtime Deployments')
print('  ✓ Consistent Environment')
print('  ✓ Resource Management')
print('  ✓ Easy Rollbacks')

print('\n[NEW CI/CD WORKFLOW]')
print('1. Build Application Docker Image')
print('2. Push Image to Registry (optional)')
print('3. Deploy via docker-compose')
print('4. Health Check Container')
print('5. Route Traffic to New Container')
print('6. Remove Old Container')

print('\n[IMPLEMENTATION STATUS]')
docker_installed = bool(docker_version.get('stdout'))
docker_working = bool(hello_world.get('stdout') and 'Hello from Docker!' in hello_world['stdout'])
structure_created = bool(list_structure.get('stdout'))

print(f'  Docker Installation: {"✓ SUCCESS" if docker_installed else "✗ FAILED"}')
print(f'  Docker Functionality: {"✓ SUCCESS" if docker_working else "✗ FAILED"}')
print(f'  Container Structure: {"✓ SUCCESS" if structure_created else "✗ FAILED"}')

if docker_installed and docker_working and structure_created:
    print('\n[READY] ✓ Container environment ready for CI/CD integration')
    print('[NEXT] Update GitHub Actions workflow for container deployment')
else:
    print('\n[ISSUES] Some setup steps need attention')

print('\n[COMMANDS FOR TESTING]')
print('  Test Docker: docker run hello-world')
print('  List containers: docker ps -a')
print('  View networks: docker network ls')
print('  Build app: cd /root/mcp_containers && docker-compose build')
print('  Start services: cd /root/mcp_containers && docker-compose up -d')

print('=' * 65)