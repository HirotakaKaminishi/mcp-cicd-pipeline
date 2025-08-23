#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Configure GitHub Actions Runner with provided token
"""

import requests
import json

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

print('GitHub Actions Self-hosted Runner Configuration')
print('=' * 60)

# Configure the runner with the provided token
config_cmd = '''cd /home/actions-runner/actions-runner && sudo -u actions-runner ./config.sh --url https://github.com/HirotakaKaminishi/mcp-cicd-pipeline --token BF6BGAESVJWCAOLT6DM4A6LITGOYY --name mcp-server-runner --labels mcp-server,linux,x64,self-hosted --unattended --replace'''

print('Step 1: Configuring Runner...')
result = execute_command(config_cmd)
if result.get('stdout'):
    print('[SUCCESS] Runner configured:')
    print(result['stdout'])
elif result.get('stderr'):
    print('[WARNING] Error output:')
    print(result['stderr'])
else:
    print('[ERROR] Configuration failed:', result)

# Install and start the service
print('\nStep 2: Installing Runner Service...')
service_install_cmd = 'cd /home/actions-runner/actions-runner && sudo ./svc.sh install'
result = execute_command(service_install_cmd)
if result.get('returncode') == 0:
    print('[SUCCESS] Service installed')
else:
    print('[INFO] Service installation:', result.get('stderr', 'Unknown error'))

print('\nStep 3: Starting Runner Service...')
service_start_cmd = 'cd /home/actions-runner/actions-runner && sudo ./svc.sh start'
result = execute_command(service_start_cmd)
if result.get('returncode') == 0:
    print('[SUCCESS] Service started')
else:
    print('[INFO] Service start:', result.get('stderr', 'Unknown error'))

# Enable service for auto-start
print('\nStep 4: Enabling Auto-start...')
enable_cmd = 'sudo systemctl enable actions-runner.service'
result = execute_command(enable_cmd)
if result.get('returncode') == 0:
    print('[SUCCESS] Auto-start enabled')
else:
    print('[INFO] Auto-start enable:', result.get('stderr', 'Unknown error'))

# Verify runner status
print('\nStep 5: Verifying Runner Status...')
status_cmd = 'cd /home/actions-runner/actions-runner && sudo ./svc.sh status'
result = execute_command(status_cmd)
if result.get('stdout'):
    print('[STATUS]:', result['stdout'])

# Check if runner is configured
print('\nStep 6: Checking Configuration Files...')
check_cmd = 'ls -la /home/actions-runner/actions-runner/.runner /home/actions-runner/actions-runner/.credentials 2>/dev/null || echo "Files not found"'
result = execute_command(check_cmd)
if result.get('stdout'):
    print('[FILES]:', result['stdout'])

print('\n' + '=' * 60)
print('Configuration Complete! Check GitHub Repository Settings.')
print('URL: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')