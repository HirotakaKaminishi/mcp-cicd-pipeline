#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Download GitHub Actions Runner using wget with retry
"""

import requests
import json

def execute_command(command, timeout=300):
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

print('GitHub Actions Runner Download with wget')
print('=' * 60)

# Clean up
print('\nStep 1: Cleaning up...')
cmd = 'cd /home/actions-runner && rm -rf actions-runner && mkdir actions-runner'
execute_command(cmd)
print('[OK] Cleaned up')

# Try wget with retry options
print('\nStep 2: Downloading with wget (retry enabled)...')
print('This will take several minutes...')
cmd = '''cd /home/actions-runner/actions-runner && wget --tries=10 --timeout=30 --continue --progress=dot:giga https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz'''
result = execute_command(cmd, timeout=300)
if result.get('stdout'):
    print('[WGET Output]:', result['stdout'][-500:] if len(result['stdout']) > 500 else result['stdout'])
if result.get('stderr'):
    print('[WGET Errors]:', result['stderr'][-500:] if len(result['stderr']) > 500 else result['stderr'])

# Check file size
print('\nStep 3: Checking downloaded file...')
cmd = 'ls -lh /home/actions-runner/actions-runner/*.tar.gz'
result = execute_command(cmd)
if result.get('stdout'):
    print('[FILE]:', result['stdout'].strip())
    # Check if file size is reasonable (should be > 100MB)
    if '100M' in result['stdout'] or '101M' in result['stdout'] or '102M' in result['stdout']:
        print('[OK] File size looks correct!')
    else:
        print('[WARNING] File size may be incorrect. Expected ~101MB')

# Try to get file info
print('\nStep 4: File information...')
cmd = 'file /home/actions-runner/actions-runner/*.tar.gz && du -h /home/actions-runner/actions-runner/*.tar.gz'
result = execute_command(cmd)
if result.get('stdout'):
    print('[INFO]:', result['stdout'])

print('\n' + '=' * 60)
print('Download attempt complete.')
print('\nIf download failed, please try:')
print('1. Download on your local PC from:')
print('   https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz')
print('2. Transfer to MCP server:')
print('   scp actions-runner-linux-x64-2.327.1.tar.gz root@192.168.111.200:/home/actions-runner/actions-runner/')
print('3. Then extract and configure:')
print('   cd /home/actions-runner/actions-runner')
print('   tar xzf actions-runner-linux-x64-2.327.1.tar.gz')
print('   chown -R actions-runner:actions-runner .')
print('   sudo -u actions-runner ./config.sh --url https://github.com/HirotakaKaminishi/mcp-cicd-pipeline --token BF6BGAESVJWCAOLT6DM4A6LITGOYY')