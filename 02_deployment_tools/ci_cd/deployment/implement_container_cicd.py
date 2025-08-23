#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Implement Container-based CI/CD Pipeline
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

print('Implementing Container-based CI/CD Pipeline')
print('=' * 55)

# 1. Test current Docker setup
print('\n[1] Verifying Docker Environment...')
docker_info = execute_mcp_command('docker info | head -10')
if docker_info.get('stdout'):
    print('[DOCKER] Docker daemon info:')
    for line in docker_info['stdout'].split('\n')[:8]:
        if line.strip():
            print(f'  {line}')

# Check networks
networks = execute_mcp_command('docker network ls')
if networks.get('stdout'):
    print('\n[NETWORKS] Available Docker networks:')
    for line in networks['stdout'].split('\n'):
        if line.strip() and ('mcp-network' in line or 'NETWORK' in line):
            print(f'  {line}')

# 2. Copy current application files to container structure
print('\n[2] Preparing Application for Containerization...')

# Copy current application to container build directory
copy_app = execute_mcp_command('cp -r /root/mcp_project/current/* /root/mcp_containers/app/ 2>/dev/null || echo "Copying latest release..."')
print(f'[COPY] Application files: {"Copied" if copy_app.get("returncode") == 0 else "Using alternative"}')

# Copy from latest release if current doesn't exist
latest_release = execute_mcp_command('ls -t /root/mcp_project/releases/ | head -1')
if latest_release.get('stdout'):
    release_dir = latest_release['stdout'].strip()
    copy_from_release = execute_mcp_command(f'cp -r /root/mcp_project/releases/{release_dir}/* /root/mcp_containers/app/')
    print(f'[RELEASE] Copied from latest release: {release_dir}')

# Verify files copied
app_files = execute_mcp_command('ls -la /root/mcp_containers/app/')
if app_files.get('stdout'):
    print('[APP FILES] Container app directory:')
    for line in app_files['stdout'].split('\n')[:8]:
        if line.strip() and not line.startswith('total'):
            print(f'  {line}')

# 3. Build container image
print('\n[3] Building Container Image...')
build_image = execute_mcp_command('cd /root/mcp_containers && docker build -t mcp-app:latest ./app')

if build_image.get('returncode') == 0:
    print('[BUILD] Container image built successfully')
    if build_image.get('stdout'):
        output_lines = build_image['stdout'].split('\n')
        for line in output_lines[-5:]:  # Last 5 lines
            if line.strip():
                print(f'  {line}')
else:
    print('[BUILD] Container build failed')
    if build_image.get('stderr'):
        print(f'[BUILD ERROR] {build_image["stderr"][:300]}')

# Check built images
list_images = execute_mcp_command('docker images | grep mcp-app')
if list_images.get('stdout'):
    print(f'[IMAGES] Built image: {list_images["stdout"].strip()}')

# 4. Test container deployment
print('\n[4] Testing Container Deployment...')

# Stop current systemd service
stop_service = execute_mcp_command('systemctl stop mcp-app.service')
print(f'[STOP] Systemd service stopped: {"Success" if stop_service.get("returncode") == 0 else "Failed"}')

# Start container using docker-compose
print('[START] Starting container with docker-compose...')
start_containers = execute_mcp_command('cd /root/mcp_containers && docker-compose up -d')

if start_containers.get('returncode') == 0:
    print('[COMPOSE] Containers started successfully')
    
    # Wait for containers to be ready
    print('[WAIT] Waiting for containers to start...')
    time.sleep(10)
    
    # Check container status
    container_status = execute_mcp_command('docker ps')
    if container_status.get('stdout'):
        print('[CONTAINERS] Running containers:')
        for line in container_status['stdout'].split('\n'):
            if 'mcp-' in line or 'CONTAINER' in line:
                print(f'  {line}')
else:
    print('[COMPOSE] Container startup failed')
    if start_containers.get('stderr'):
        print(f'[COMPOSE ERROR] {start_containers["stderr"][:200]}')

# 5. Test application endpoints
print('\n[5] Testing Containerized Application...')

# Test direct container access (port 3000)
direct_test = execute_mcp_command('curl -s http://localhost:3000/ --connect-timeout 10')
if direct_test.get('stdout'):
    try:
        app_data = json.loads(direct_test['stdout'])
        print('[DIRECT] Container app response:')
        for key, value in list(app_data.items())[:4]:
            print(f'  {key}: {value}')
    except:
        print(f'[DIRECT] Raw response: {direct_test["stdout"][:150]}')
else:
    print('[DIRECT] Container app not responding on port 3000')

# Test nginx proxy access (port 80)
proxy_test = execute_mcp_command('curl -s http://localhost/ --connect-timeout 10')
if proxy_test.get('stdout'):
    try:
        proxy_data = json.loads(proxy_test['stdout'])
        print('\n[PROXY] Nginx proxy response:')
        for key, value in list(proxy_data.items())[:4]:
            print(f'  {key}: {value}')
    except:
        print(f'\n[PROXY] Raw proxy response: {proxy_test["stdout"][:150]}')
else:
    print('\n[PROXY] Nginx proxy not responding on port 80')

# Test health endpoints
health_direct = execute_mcp_command('curl -s http://localhost:3000/health --connect-timeout 5')
health_proxy = execute_mcp_command('curl -s http://localhost/health --connect-timeout 5')

if health_direct.get('stdout'):
    print('\n[HEALTH DIRECT] Container health check: OK')
if health_proxy.get('stdout'):
    print('[HEALTH PROXY] Proxy health check: OK')

# 6. Container logs and diagnostics
print('\n[6] Container Diagnostics...')
app_logs = execute_mcp_command('docker logs mcp-app --tail 5')
if app_logs.get('stdout'):
    print('[APP LOGS] Application container logs:')
    for line in app_logs['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

nginx_logs = execute_mcp_command('docker logs mcp-nginx --tail 3')
if nginx_logs.get('stdout'):
    print('\n[NGINX LOGS] Nginx container logs:')
    for line in nginx_logs['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('\n' + '=' * 55)
print('CONTAINER DEPLOYMENT ASSESSMENT')
print('=' * 55)

# Final assessment
containers_running = execute_mcp_command('docker ps -q | wc -l')
app_responding = bool(direct_test.get('stdout'))
proxy_working = bool(proxy_test.get('stdout'))

container_count = int(containers_running.get('stdout', '0').strip()) if containers_running.get('stdout') else 0

print(f'\n[STATUS] Container deployment status:')
print(f'  Running containers: {container_count}')
print(f'  Application responding: {"YES" if app_responding else "NO"}')
print(f'  Nginx proxy working: {"YES" if proxy_working else "NO"}')

if container_count >= 2 and app_responding:
    print('\n[SUCCESS] Container deployment is working!')
    
    print('\n[NEXT PHASE] Update CI/CD pipeline for containers:')
    print('1. Modify GitHub Actions workflow')
    print('2. Replace systemd deployment with container deployment')
    print('3. Implement zero-downtime container replacement')
    print('4. Add container health monitoring')
    
elif container_count > 0:
    print('\n[PARTIAL] Containers running but may need configuration')
    
else:
    print('\n[ISSUE] Container deployment needs troubleshooting')

print('\n[DEPLOYMENT COMPARISON]')
print('Current systemd approach:')
print('  - Direct host deployment')
print('  - systemctl restart for updates')
print('  - Single process management')

print('\nNew container approach:')
print('  - Isolated environment')
print('  - docker-compose up/down for updates')
print('  - Multi-container orchestration')
print('  - Better resource isolation')

print('\n[RECOMMENDED ACTION]')
if container_count >= 2 and app_responding and proxy_working:
    print('PROCEED: Update CI/CD pipeline for container deployment')
    print('The container environment is ready for production use')
elif app_responding:
    print('INVESTIGATE: Fix proxy configuration, then proceed')
else:
    print('DEBUG: Resolve container issues before CI/CD integration')

print('=' * 55)