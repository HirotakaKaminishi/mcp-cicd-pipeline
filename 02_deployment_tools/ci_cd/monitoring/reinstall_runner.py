#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Reinstall GitHub Actions Runner
"""

import requests
import json
import time

def execute_command(command):
    url = 'http://192.168.111.200:8080'
    payload = {
        'jsonrpc': '2.0',
        'method': 'execute_command',
        'params': {'command': command},
        'id': 1
    }
    try:
        response = requests.post(url, json=payload, timeout=60)
        if response.status_code == 200:
            result = response.json()
            if 'result' in result:
                return result['result']
    except Exception as e:
        return {'error': str(e)}
    return {'error': 'Command failed'}

print('GitHub Actions Runner Reinstallation')
print('=' * 60)

# Step 1: Clean up existing runner directory
print('\nStep 1: Cleaning up existing runner directory...')
cleanup_cmd = 'rm -rf /home/actions-runner/actions-runner && mkdir -p /home/actions-runner/actions-runner'
result = execute_command(cleanup_cmd)
print('[CLEANUP] Done')

# Step 2: Download runner
print('\nStep 2: Downloading GitHub Actions Runner...')
download_cmd = '''cd /home/actions-runner/actions-runner && curl -o actions-runner-linux-x64-2.319.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.319.1/actions-runner-linux-x64-2.319.1.tar.gz'''
result = execute_command(download_cmd)
if result.get('returncode') == 0:
    print('[DOWNLOAD] Success')
else:
    print('[DOWNLOAD] May have failed, continuing...')

# Step 3: Extract runner
print('\nStep 3: Extracting runner archive...')
extract_cmd = 'cd /home/actions-runner/actions-runner && tar xzf actions-runner-linux-x64-2.319.1.tar.gz'
result = execute_command(extract_cmd)
if result.get('returncode') == 0:
    print('[EXTRACT] Success')
else:
    print('[EXTRACT] Error:', result.get('stderr', 'Unknown'))

# Step 4: Set permissions
print('\nStep 4: Setting permissions...')
perm_cmd = 'chown -R actions-runner:actions-runner /home/actions-runner && chmod +x /home/actions-runner/actions-runner/*.sh'
result = execute_command(perm_cmd)
print('[PERMISSIONS] Set')

# Step 5: Check extraction
print('\nStep 5: Verifying extraction...')
check_cmd = 'ls -la /home/actions-runner/actions-runner/ | head -20'
result = execute_command(check_cmd)
if result.get('stdout'):
    print('[FILES] Found:')
    for line in result['stdout'].split('\n')[:10]:
        if line.strip():
            print('  ', line)

# Step 6: Check for svc.sh
print('\nStep 6: Checking for svc.sh...')
svc_check = 'test -f /home/actions-runner/actions-runner/svc.sh && echo "svc.sh EXISTS" || echo "svc.sh NOT FOUND"'
result = execute_command(svc_check)
print('[SVC.SH]:', result.get('stdout', 'Unknown'))

# Step 7: Configure runner with token
print('\nStep 7: Configuring runner with GitHub token...')
config_cmd = '''cd /home/actions-runner/actions-runner && sudo -u actions-runner ./config.sh --url https://github.com/HirotakaKaminishi/mcp-cicd-pipeline --token BF6BGAESVJWCAOLT6DM4A6LITGOYY --name mcp-server-runner --labels mcp-server,linux,x64,self-hosted --unattended --replace'''
result = execute_command(config_cmd)
if result.get('stdout'):
    print('[CONFIG] Output:')
    for line in result['stdout'].split('\n')[:20]:
        if line.strip():
            print('  ', line)
if result.get('stderr'):
    print('[CONFIG] Errors:')
    for line in result['stderr'].split('\n')[:10]:
        if line.strip():
            print('  ', line)

# Step 8: Install service (if svc.sh exists)
print('\nStep 8: Installing service...')
service_cmd = 'cd /home/actions-runner/actions-runner && test -f svc.sh && sudo ./svc.sh install || echo "svc.sh not available"'
result = execute_command(service_cmd)
print('[SERVICE]:', result.get('stdout', result.get('stderr', 'Unknown')))

# Step 9: Start service
print('\nStep 9: Starting service...')
start_cmd = 'cd /home/actions-runner/actions-runner && test -f svc.sh && sudo ./svc.sh start || echo "svc.sh not available"'
result = execute_command(start_cmd)
print('[START]:', result.get('stdout', result.get('stderr', 'Unknown')))

# Step 10: Final status check
print('\nStep 10: Final status check...')
status_cmd = 'ps aux | grep -i runner | grep -v grep'
result = execute_command(status_cmd)
if result.get('stdout'):
    print('[RUNNING] Processes found:')
    print(result['stdout'])
else:
    print('[RUNNING] No runner processes found')

check_files = 'ls -la /home/actions-runner/actions-runner/.runner /home/actions-runner/actions-runner/.credentials 2>/dev/null || echo "Config files not found"'
result = execute_command(check_files)
print('[CONFIG FILES]:', result.get('stdout', 'Not found'))

print('\n' + '=' * 60)
print('Installation attempt complete!')
print('Check: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')