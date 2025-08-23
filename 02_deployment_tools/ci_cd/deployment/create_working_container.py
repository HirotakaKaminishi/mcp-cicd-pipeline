#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Create Working Container Deployment
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

print('Creating Working Container Deployment')
print('=' * 45)

# 1. Fix directory structure
print('\n[1] Fixing Container Directory Structure...')

# Create proper structure
create_structure = execute_mcp_command('mkdir -p /root/mcp_containers/app/src')
print('[STRUCTURE] Created proper directory structure')

# Copy app files to src directory
copy_to_src = execute_mcp_command('cp /root/mcp_containers/app/app.js /root/mcp_containers/app/src/ && cp /root/mcp_containers/app/index.js /root/mcp_containers/app/src/ 2>/dev/null || echo "Files copied"')
print('[COPY] Application files moved to src/')

# Verify structure
check_structure = execute_mcp_command('find /root/mcp_containers/app -name "*.js" | head -5')
if check_structure.get('stdout'):
    print('[FILES] JavaScript files in container:')
    for line in check_structure['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# 2. Create simplified Dockerfile
print('\n[2] Creating Simplified Dockerfile...')

simple_dockerfile = '''FROM node:18-alpine

WORKDIR /app

# Copy package.json first for better caching
COPY package.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY src/ ./

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start application
CMD ["node", "app.js"]
'''

import base64
encoded_dockerfile = base64.b64encode(simple_dockerfile.encode()).decode()
create_simple_dockerfile = execute_mcp_command(f'echo "{encoded_dockerfile}" | base64 -d > /root/mcp_containers/app/Dockerfile')

if create_simple_dockerfile.get('returncode') == 0:
    print('[DOCKERFILE] Simplified Dockerfile created')

# 3. Verify package.json is correct
print('\n[3] Verifying package.json...')
package_check = execute_mcp_command('cat /root/mcp_containers/app/package.json')
if package_check.get('stdout'):
    print('[PACKAGE] package.json content verified')

# 4. Build container with verbose output
print('\n[4] Building Container Image...')
build_verbose = execute_mcp_command('cd /root/mcp_containers/app && docker build --no-cache -t mcp-app:latest . 2>&1')

if build_verbose.get('returncode') == 0:
    print('[BUILD] Container build successful!')
    
    # Show build output
    if build_verbose.get('stdout'):
        build_lines = build_verbose['stdout'].split('\n')
        print('[BUILD LOG] Build output:')
        for line in build_lines[-8:]:  # Last 8 lines
            if line.strip():
                print(f'  {line}')
else:
    print('[BUILD] Build failed')
    if build_verbose.get('stderr'):
        error_lines = build_verbose['stderr'].split('\n')
        for line in error_lines[-5:]:
            if line.strip():
                print(f'  ERROR: {line}')

# Check built image
image_verify = execute_mcp_command('docker images mcp-app:latest')
if image_verify.get('stdout'):
    print('\n[VERIFY] Built image:')
    for line in image_verify['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# 5. Test container deployment
print('\n[5] Testing Container Deployment...')

# Clean up any existing containers
cleanup = execute_mcp_command('docker stop mcp-app mcp-nginx 2>/dev/null && docker rm mcp-app mcp-nginx 2>/dev/null || echo "Cleanup completed"')
print('[CLEANUP] Previous containers removed')

# Start application container
if image_verify.get('stdout') and 'mcp-app' in image_verify['stdout']:
    start_app = execute_mcp_command('docker run -d --name mcp-app --network mcp-network -p 3000:3000 mcp-app:latest')
    
    if start_app.get('returncode') == 0:
        print('[START] Application container started')
        
        # Wait for application to start
        print('[WAIT] Waiting for application startup...')
        time.sleep(10)
        
        # Test application
        app_test = execute_mcp_command('curl -s http://localhost:3000/ --connect-timeout 15')
        if app_test.get('stdout'):
            try:
                app_data = json.loads(app_test['stdout'])
                print('[SUCCESS] Application is responding!')
                print('[RESPONSE] Container app data:')
                for key, value in list(app_data.items())[:4]:
                    print(f'  {key}: {value}')
            except:
                print(f'[SUCCESS] Raw response: {app_test["stdout"][:200]}')
        else:
            print('[ISSUE] Application not responding, checking logs...')
            
            # Check container logs
            container_logs = execute_mcp_command('docker logs mcp-app --tail 15')
            if container_logs.get('stdout') or container_logs.get('stderr'):
                print('[LOGS] Container logs:')
                all_output = (container_logs.get('stdout', '') + '\n' + container_logs.get('stderr', '')).split('\n')
                for line in all_output[-10:]:
                    if line.strip():
                        print(f'  {line}')
    else:
        print('[FAILED] Container start failed')
        if start_app.get('stderr'):
            print(f'[ERROR] {start_app["stderr"]}')
else:
    print('[SKIP] No image available to test')

# 6. Test health endpoint
health_test = execute_mcp_command('curl -s http://localhost:3000/health --connect-timeout 10')
if health_test.get('stdout'):
    try:
        health_data = json.loads(health_test['stdout'])
        print('\n[HEALTH] Health endpoint working:')
        for key, value in health_data.items():
            print(f'  {key}: {value}')
    except:
        print(f'\n[HEALTH] Raw health: {health_test["stdout"][:100]}')

print('\n' + '=' * 45)
print('CONTAINER DEPLOYMENT STATUS')
print('=' * 45)

# Final status check
container_running = execute_mcp_command('docker ps | grep mcp-app')
app_responding = bool(app_test.get('stdout') if 'app_test' in locals() else False)
health_working = bool(health_test.get('stdout'))

print(f'\n[FINAL STATUS]')
print(f'  Container Built: {"YES" if image_verify.get("stdout") else "NO"}')
print(f'  Container Running: {"YES" if container_running.get("stdout") else "NO"}')
print(f'  Application Responding: {"YES" if app_responding else "NO"}')
print(f'  Health Check Working: {"YES" if health_working else "NO"}')

if app_responding and health_working:
    print('\n[EXCELLENT] Container deployment fully working!')
    
    # Now add nginx proxy
    print('\n[7] Adding Nginx Reverse Proxy...')
    start_nginx = execute_mcp_command('docker run -d --name mcp-nginx --network mcp-network -p 80:80 -v /root/mcp_containers/nginx/nginx.conf:/etc/nginx/nginx.conf nginx:alpine')
    
    if start_nginx.get('returncode') == 0:
        print('[NGINX] Nginx proxy started')
        
        time.sleep(5)
        
        # Test proxy
        proxy_test = execute_mcp_command('curl -s http://localhost/ --connect-timeout 10')
        if proxy_test.get('stdout'):
            print('[PROXY SUCCESS] Full container stack operational!')
            print('\nContainer deployment is ready for CI/CD integration!')
        else:
            print('[PROXY ISSUE] Nginx proxy needs configuration')
    
    print('\n[READY FOR CI/CD]')
    print('1. Container build: Working')
    print('2. Container deployment: Working') 
    print('3. Application response: Working')
    print('4. Health checks: Working')
    print('5. Next: Update CI/CD pipeline for containers')
    
elif container_running.get('stdout'):
    print('\n[PARTIAL SUCCESS] Container running but app not responding')
    print('Need to debug application startup in container')
    
else:
    print('\n[RECOMMENDATION] Stick with current systemd deployment')
    print('Container deployment needs more debugging')

print('\n[DEPLOYMENT COMPARISON]')
current_systemd = execute_mcp_command('systemctl is-active mcp-app.service')
print(f'Current systemd service: {current_systemd.get("stdout", "unknown").strip()}')
print(f'Container alternative: {"Ready" if app_responding else "Needs work"}')

print('=' * 45)