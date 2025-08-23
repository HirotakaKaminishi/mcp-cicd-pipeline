#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix Container Deployment Issues
"""

import requests
import json
import time

def execute_mcp_command(command, timeout=180):
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

print('Fixing Container Deployment Issues')
print('=' * 45)

# 1. Install docker-compose
print('\n[1] Installing Docker Compose...')
install_compose = execute_mcp_command('dnf install -y docker-compose-plugin')

if install_compose.get('returncode') == 0:
    print('[COMPOSE] Docker Compose plugin installed')
else:
    print('[COMPOSE] Plugin installation failed, trying alternative...')
    
    # Alternative installation
    alt_install = execute_mcp_command('curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose')
    if alt_install.get('returncode') == 0:
        print('[COMPOSE] Docker Compose binary installed')

# Verify docker-compose installation
compose_check = execute_mcp_command('docker compose version || docker-compose version')
if compose_check.get('stdout'):
    print(f'[VERIFY] Docker Compose: {compose_check["stdout"].strip()}')

# 2. Fix Dockerfile issues
print('\n[2] Fixing Container Build Issues...')

# Check Dockerfile content
dockerfile_check = execute_mcp_command('cat /root/mcp_containers/app/Dockerfile')
if dockerfile_check.get('stdout'):
    print('[DOCKERFILE] Current Dockerfile content:')
    for line in dockerfile_check['stdout'].split('\n')[:10]:
        if line.strip():
            print(f'  {line}')

# Check if package.json exists
package_check = execute_mcp_command('ls -la /root/mcp_containers/app/package.json')
if not package_check.get('stdout'):
    print('[PACKAGE] package.json not found, creating...')
    
    package_content = '''{
  "name": "mcp-container-app",
  "version": "1.1.0",
  "description": "MCP Containerized Application",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "test": "echo \\"Error: no test specified\\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "keywords": ["mcp", "container", "cicd"],
  "author": "MCP CI/CD Pipeline",
  "license": "MIT"
}'''
    
    import base64
    encoded_package = base64.b64encode(package_content.encode()).decode()
    create_package = execute_mcp_command(f'echo "{encoded_package}" | base64 -d > /root/mcp_containers/app/package.json')
    
    if create_package.get('returncode') == 0:
        print('[PACKAGE] package.json created')

# 3. Build container image manually with better error handling
print('\n[3] Building Container Image (with detailed output)...')
build_cmd = 'cd /root/mcp_containers/app && docker build -t mcp-app:latest .'
build_result = execute_mcp_command(build_cmd)

if build_result.get('returncode') == 0:
    print('[BUILD] Container build successful')
else:
    print('[BUILD] Build failed, checking details...')
    if build_result.get('stderr'):
        error_lines = build_result['stderr'].split('\n')
        for line in error_lines[-10:]:  # Last 10 lines of error
            if line.strip():
                print(f'  {line}')

# Check if image was created
image_check = execute_mcp_command('docker images mcp-app')
if image_check.get('stdout'):
    print('[IMAGES] Built images:')
    for line in image_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# 4. Try simpler container deployment without compose first
print('\n[4] Testing Simple Container Deployment...')

# Stop any existing containers
stop_containers = execute_mcp_command('docker stop mcp-app mcp-nginx 2>/dev/null || echo "No containers to stop"')
remove_containers = execute_mcp_command('docker rm mcp-app mcp-nginx 2>/dev/null || echo "No containers to remove"')

print(f'[CLEANUP] Existing containers: {"Cleaned" if stop_containers.get("returncode") == 0 else "No cleanup needed"}')

# Start just the app container first
start_app = execute_mcp_command('docker run -d --name mcp-app --network mcp-network -p 3000:3000 mcp-app:latest')

if start_app.get('returncode') == 0:
    print('[APP] Application container started')
    
    # Wait for startup
    time.sleep(8)
    
    # Test container
    test_app = execute_mcp_command('curl -s http://localhost:3000/ --connect-timeout 10')
    if test_app.get('stdout'):
        try:
            app_data = json.loads(test_app['stdout'])
            print('[TEST] Container app response:')
            for key, value in list(app_data.items())[:3]:
                print(f'  {key}: {value}')
        except:
            print(f'[TEST] Raw response: {test_app["stdout"][:100]}')
    else:
        print('[TEST] Container not responding, checking logs...')
        
        # Get container logs
        container_logs = execute_mcp_command('docker logs mcp-app --tail 10')
        if container_logs.get('stdout') or container_logs.get('stderr'):
            print('[LOGS] Container logs:')
            all_logs = (container_logs.get('stdout', '') + container_logs.get('stderr', '')).split('\n')
            for line in all_logs[-8:]:
                if line.strip():
                    print(f'  {line}')
else:
    print('[APP] Container start failed')
    if start_app.get('stderr'):
        print(f'[ERROR] {start_app["stderr"]}')

# 5. Check container status
print('\n[5] Container Status Check...')
container_status = execute_mcp_command('docker ps -a')
if container_status.get('stdout'):
    print('[CONTAINERS] All containers:')
    for line in container_status['stdout'].split('\n'):
        if 'mcp-' in line or 'CONTAINER' in line:
            print(f'  {line}')

# Test health endpoint
health_test = execute_mcp_command('curl -s http://localhost:3000/health --connect-timeout 5')
if health_test.get('stdout'):
    print(f'\n[HEALTH] Health check: {health_test["stdout"][:100]}')

print('\n' + '=' * 45)
print('CONTAINER TROUBLESHOOTING RESULTS')
print('=' * 45)

# Final assessment
app_container = execute_mcp_command('docker ps | grep mcp-app')
app_responding = bool(test_app.get('stdout') if 'test_app' in locals() else False)

print(f'\n[STATUS] Troubleshooting results:')
print(f'  Docker Compose: {"Available" if compose_check.get("stdout") else "Missing"}')
print(f'  Container Built: {"Yes" if image_check.get("stdout") else "No"}')
print(f'  Container Running: {"Yes" if app_container.get("stdout") else "No"}')
print(f'  Application Responding: {"Yes" if app_responding else "No"}')

if app_responding:
    print('\n[SUCCESS] Basic container deployment working!')
    print('\n[NEXT] Add Nginx proxy and update CI/CD pipeline')
    
    # Start Nginx container
    print('\n[6] Adding Nginx Proxy Container...')
    start_nginx = execute_mcp_command('docker run -d --name mcp-nginx --network mcp-network -p 80:80 -v /root/mcp_containers/nginx/nginx.conf:/etc/nginx/nginx.conf nginx:alpine')
    
    if start_nginx.get('returncode') == 0:
        print('[NGINX] Nginx proxy started')
        
        time.sleep(5)
        
        # Test proxy
        proxy_test = execute_mcp_command('curl -s http://localhost/ --connect-timeout 10')
        if proxy_test.get('stdout'):
            print('[PROXY] Nginx proxy working')
            print('Full container stack is operational!')
        else:
            print('[PROXY] Nginx proxy needs configuration')
    
elif app_container.get('stdout'):
    print('\n[PARTIAL] Container running but not responding')
    print('Check application logs and configuration')
    
else:
    print('\n[ISSUE] Container deployment needs more work')
    print('Consider hybrid approach: containers for some services, systemd for others')

print('\n[DEPLOYMENT STRATEGY OPTIONS]')
print('1. Full container deployment (if working)')
print('2. Hybrid deployment (containers + systemd)')
print('3. Continue with systemd (if containers too complex)')

print('=' * 45)