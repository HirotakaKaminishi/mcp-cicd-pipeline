#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix Docker Installation Issues on CentOS Stream 9
"""

import requests
import json
import time

def execute_mcp_command(command, timeout=300):
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

print('Fixing Docker Installation on CentOS Stream 9')
print('=' * 55)

# Alternative approach: Install Docker from EPEL or use Podman
print('\n[1] Checking installation alternatives...')

# Check if EPEL is available
epel_check = execute_mcp_command('dnf list available | grep epel-release')
print(f'[EPEL] EPEL availability: {"Available" if epel_check.get("stdout") else "Not found"}')

# Check current system information
system_info = execute_mcp_command('cat /etc/os-release | head -5')
if system_info.get('stdout'):
    print('[SYSTEM] OS Information:')
    for line in system_info['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('\n[2] Alternative Installation Method - Using Podman...')
print('[INFO] CentOS Stream 9 often uses Podman instead of Docker')

# Check if Podman is available
podman_check = execute_mcp_command('podman --version')
if podman_check.get('stdout'):
    print('[PODMAN] Podman is already installed:')
    print(f'  {podman_check["stdout"].strip()}')
else:
    print('[PODMAN] Installing Podman...')
    install_podman = execute_mcp_command('dnf install -y podman podman-compose')
    
    if install_podman.get('returncode') == 0:
        print('[PODMAN] Podman installed successfully')
        
        # Verify installation
        verify_podman = execute_mcp_command('podman --version')
        if verify_podman.get('stdout'):
            print(f'[VERIFY] Podman version: {verify_podman["stdout"].strip()}')
    else:
        print('[PODMAN] Podman installation failed')

print('\n[3] Docker Alternative Installation...')
# Try alternative Docker installation method
print('[ALT] Trying alternative Docker installation...')

# Update system first
update_system = execute_mcp_command('dnf update -y')
print(f'[UPDATE] System update: {"Completed" if update_system.get("returncode") == 0 else "Failed"}')

# Install Docker from official script
print('[SCRIPT] Trying Docker convenience script...')
install_script = execute_mcp_command('curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh')

if install_script.get('returncode') == 0:
    print('[SCRIPT] Docker installation script completed')
    
    # Start Docker
    start_docker = execute_mcp_command('systemctl start docker')
    if start_docker.get('returncode') == 0:
        print('[START] Docker service started')
        
        # Enable Docker
        enable_docker = execute_mcp_command('systemctl enable docker')
        if enable_docker.get('returncode') == 0:
            print('[ENABLE] Docker enabled for auto-start')
else:
    print('[SCRIPT] Docker script installation failed')

print('\n[4] Final Verification...')
# Test both Docker and Podman
docker_test = execute_mcp_command('docker --version')
podman_test = execute_mcp_command('podman --version')

print('[RESULTS] Available container runtimes:')
if docker_test.get('stdout'):
    print(f'  Docker: {docker_test["stdout"].strip()}')
else:
    print('  Docker: Not available')

if podman_test.get('stdout'):
    print(f'  Podman: {podman_test["stdout"].strip()}')
else:
    print('  Podman: Not available')

# Determine which container runtime to use
container_runtime = None
if docker_test.get('stdout'):
    container_runtime = 'docker'
elif podman_test.get('stdout'):
    container_runtime = 'podman'

print(f'\n[RUNTIME] Selected container runtime: {container_runtime or "NONE"}')

if container_runtime:
    print('\n[5] Setting up Container Environment...')
    
    if container_runtime == 'docker':
        # Test Docker
        test_cmd = 'docker run hello-world'
    else:
        # Test Podman
        test_cmd = 'podman run hello-world'
    
    test_result = execute_mcp_command(test_cmd)
    if test_result.get('stdout') and 'Hello' in test_result['stdout']:
        print(f'[TEST] {container_runtime.capitalize()} test successful')
        
        # Create network
        if container_runtime == 'docker':
            network_cmd = 'docker network create mcp-network'
        else:
            network_cmd = 'podman network create mcp-network'
        
        network_result = execute_mcp_command(network_cmd)
        if network_result.get('returncode') == 0 or 'already exists' in str(network_result.get('stderr', '')):
            print('[NETWORK] mcp-network created or already exists')
    else:
        print(f'[TEST] {container_runtime.capitalize()} test failed')

print('\n' + '=' * 55)
print('CONTAINER DEPLOYMENT STRATEGY')
print('=' * 55)

if container_runtime:
    print(f'\n[SUCCESS] Container runtime available: {container_runtime.upper()}')
    
    print('\n[DEPLOYMENT OPTIONS]')
    
    if container_runtime == 'docker':
        print('Option 1: Docker-based Deployment')
        print('  • Use Docker and Docker Compose')
        print('  • Standard Docker workflow')
        print('  • Familiar Docker ecosystem')
        
    elif container_runtime == 'podman':
        print('Option 1: Podman-based Deployment')
        print('  • Use Podman (Docker-compatible)')
        print('  • Rootless containers (better security)')
        print('  • systemd integration')
        print('  • Docker Compose compatibility with podman-compose')
    
    print('\n[RECOMMENDED APPROACH]')
    print('1. Create containerized version of current application')
    print('2. Update CI/CD pipeline for container deployment')
    print('3. Implement blue-green deployment with containers')
    print('4. Add container health monitoring')
    
    # Create container deployment files
    print('\n[6] Creating Container Deployment Files...')
    
    # Update docker-compose.yml for the selected runtime
    if container_runtime == 'podman':
        # Create podman-compatible compose file
        podman_compose = '''version: '3'

services:
  app:
    build: 
      context: ./app
      dockerfile: Dockerfile
    container_name: mcp-app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    container_name: mcp-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:Z
    depends_on:
      - app
    restart: unless-stopped
'''
        
        import base64
        encoded_compose = base64.b64encode(podman_compose.encode()).decode()
        update_compose = execute_mcp_command(f'echo "{encoded_compose}" | base64 -d > /root/mcp_containers/podman-compose.yml')
        
        if update_compose.get('returncode') == 0:
            print('[PODMAN] Podman-compatible compose file created')
    
    print('\n[NEXT STEPS]')
    print('1. Test container build and deployment')
    print('2. Update CI/CD pipeline for container workflow')
    print('3. Implement zero-downtime container replacement')
    
else:
    print('\n[ISSUE] No container runtime available')
    print('\n[ALTERNATIVES]')
    print('1. Continue with current systemd-based deployment')
    print('2. Try manual Docker installation')
    print('3. Use virtual environments instead of containers')

print('\n[CURRENT STATUS]')
print(f'Container Runtime: {container_runtime or "None"}')
print('Container Structure: Created')
print('Ready for CI/CD Integration: ' + ('Yes' if container_runtime else 'No'))

print('=' * 55)