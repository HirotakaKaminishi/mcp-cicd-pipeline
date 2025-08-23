#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check GitHub Actions Debug Logs in Runner Journal
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

print('Checking GitHub Actions Debug Logs')
print('=' * 45)

# Check latest deployment log entry
print('\n[1] Latest commit deployment log...')
latest_log = execute_mcp_command('grep "bbabb23" /root/mcp_project/deployment.log')
if latest_log.get('stdout'):
    print('[FOUND] Latest commit bbabb23:')
    print(f'  {latest_log["stdout"].strip()}')

# Check runner service logs for debugging output from the latest run
print('\n[2] GitHub Actions runner debug logs (last 20 minutes)...')
debug_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --since "20 minutes ago" | grep -E "(DEBUG|Deploying|dist|MCP API|SUCCESS|ERROR)" | tail -20')

if debug_logs.get('stdout'):
    print('[DEBUG LOGS] Recent debugging output:')
    for line in debug_logs['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[NO DEBUG] No debug logs found')

# Check for any shell script execution logs
print('\n[3] Shell script execution logs...')
shell_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --since "20 minutes ago" | grep -E "(ls -la dist|jq -Rs|curl.*write_file)" | tail -15')

if shell_logs.get('stdout'):
    print('[SHELL LOGS] Shell command execution:')
    for line in shell_logs['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check for any error messages
print('\n[4] Error messages from runner...')
error_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --since "20 minutes ago" | grep -i error | tail -10')

if error_logs.get('stdout'):
    print('[ERRORS] Error messages found:')
    for line in error_logs['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[NO ERRORS] No error messages found')

# Check if jq command is available (required for JSON escaping)
print('\n[5] System tool availability...')
jq_check = execute_mcp_command('which jq && jq --version')
if jq_check.get('stdout'):
    print('[JQ] jq tool available:')
    print(f'  {jq_check["stdout"].strip()}')
else:
    print('[JQ MISSING] jq tool not available - this could be the problem!')

# Check recent file operations that might show the actual deployment
print('\n[6] Recent file operations...')
file_ops = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --since "20 minutes ago" | grep -E "(mkdir|write_file|deployment)" | tail -10')

if file_ops.get('stdout'):
    print('[FILE OPS] Recent file operations:')
    for line in file_ops['stdout'].split('\n'):
        if line.strip():
            print(f'  {line[:120]}...')

print('\n' + '=' * 45)
print('ANALYSIS')
print('=' * 45)

# Check if latest release has metadata
latest_release = execute_mcp_command('ls -t /root/mcp_project/releases/ | head -1')
if latest_release.get('stdout'):
    latest_dir = latest_release['stdout'].strip()
    
    # Check for deployment metadata file
    metadata_check = execute_mcp_command(f'ls -la /root/mcp_project/releases/{latest_dir}/deployment.json 2>/dev/null')
    if metadata_check.get('stdout'):
        print(f'[METADATA] Found deployment.json in {latest_dir}')
        
        # Read metadata
        metadata_content = execute_mcp_command(f'cat /root/mcp_project/releases/{latest_dir}/deployment.json')
        if metadata_content.get('stdout'):
            print('[CONTENT] Deployment metadata:')
            try:
                metadata = json.loads(metadata_content['stdout'])
                for key, value in metadata.items():
                    print(f'  {key}: {value}')
            except:
                print(f'  Raw: {metadata_content["stdout"]}')
    else:
        print(f'[NO METADATA] No deployment.json found in {latest_dir}')

print('\n[CONCLUSION]')
if not jq_check.get('stdout'):
    print('LIKELY CAUSE: jq tool is not installed on the runner!')
    print('This would cause the JSON escaping to fail silently.')
    print('SOLUTION: Install jq or use alternative JSON escaping method.')
else:
    print('jq tool is available, investigating other potential causes...')

print('=' * 45)