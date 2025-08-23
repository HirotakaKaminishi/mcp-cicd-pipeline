#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check Latest Deployment Details
"""

import requests
import json

def execute_mcp_command(command, timeout=60):
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

print('Latest Deployment Check - Commit a40ac26')
print('=' * 50)

# Check the latest deployment log entry
print('\n[1] Latest deployment log entry...')
latest_log = execute_mcp_command('grep "a40ac26" /root/mcp_project/deployment.log')
if latest_log.get('stdout'):
    print('[FOUND] Latest commit deployment:')
    print(f'  {latest_log["stdout"].strip()}')

# Check latest release directory
print('\n[2] Latest release directory contents...')
latest_release = execute_mcp_command('ls -t /root/mcp_project/releases/ | head -1')
if latest_release.get('stdout'):
    latest_dir = latest_release['stdout'].strip()
    print(f'[LATEST] Directory: {latest_dir}')
    
    # Check what's in the latest directory
    contents = execute_mcp_command(f'ls -la /root/mcp_project/releases/{latest_dir}/')
    if contents.get('stdout'):
        print('[CONTENTS] Files in latest release:')
        for line in contents['stdout'].split('\n'):
            if line.strip():
                print(f'  {line}')

# Check if current symlink was updated
print('\n[3] Current deployment symlink...')
current_link = execute_mcp_command('readlink /root/mcp_project/current')
if current_link.get('stdout'):
    print(f'[CURRENT] Points to: {current_link["stdout"].strip()}')

# Check deployment metadata if exists
print('\n[4] Deployment metadata...')
metadata_check = execute_mcp_command('find /root/mcp_project/releases/ -name "deployment.json" -exec cat {} \; | tail -1')
if metadata_check.get('stdout'):
    print('[METADATA] Latest deployment info:')
    try:
        metadata = json.loads(metadata_check['stdout'])
        for key, value in metadata.items():
            print(f'  {key}: {value}')
    except:
        print(f'  Raw: {metadata_check["stdout"][:200]}')

print('\n[5] Checking workflow execution logs on runner...')
runner_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --since "10 minutes ago" | grep -E "(Deploy|curl|mkdir)" | tail -10')
if runner_logs.get('stdout'):
    print('[RUNNER] Recent deployment activity:')
    for line in runner_logs['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('=' * 50)