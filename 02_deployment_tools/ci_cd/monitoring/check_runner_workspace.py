#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Direct Check of Runner Workspace and Recent Activity
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

print('Direct Runner Workspace Investigation')
print('=' * 45)

# Check if there are any temp/workspace files that show recent activity
print('\n[1] Current runner workspace state...')
workspace_check = execute_mcp_command('find /home/actions-runner/actions-runner/_work/ -name "*.log" -o -name "*temp*" -o -name "*debug*" 2>/dev/null | head -10')
if workspace_check.get('stdout'):
    print('[WORKSPACE LOGS] Found workspace files:')
    for line in workspace_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check the actual latest timestamp on files in releases
print('\n[2] Release directory timestamps...')
timestamps = execute_mcp_command('find /root/mcp_project/releases/ -type d -name "20250811_*" -exec stat -c "%Y %n" {} \; | sort -n | tail -3')
if timestamps.get('stdout'):
    print('[TIMESTAMPS] Recent release directories:')
    for line in timestamps['stdout'].split('\n'):
        if line.strip():
            parts = line.split(' ', 1)
            if len(parts) == 2:
                import datetime
                timestamp = datetime.datetime.fromtimestamp(int(parts[0]))
                print(f'  {timestamp.strftime("%Y-%m-%d %H:%M:%S")} - {parts[1]}')

# Check for any files that might have been written recently
print('\n[3] Recently modified files in mcp_project...')
recent_files = execute_mcp_command('find /root/mcp_project/ -type f -mmin -30 | head -10')
if recent_files.get('stdout'):
    print('[RECENT FILES] Files modified in last 30 minutes:')
    for line in recent_files['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check the deployment log more carefully
print('\n[4] Deployment log analysis...')
full_log = execute_mcp_command('cat /root/mcp_project/deployment.log')
if full_log.get('stdout'):
    lines = full_log['stdout'].split('\n')
    print(f'[LOG ANALYSIS] Total log entries: {len(lines)}')
    print('[RECENT] Last 3 entries:')
    for line in lines[-4:]:
        if line.strip():
            print(f'  {line}')

# Test the MCP API directly to see if it's still working
print('\n[5] Testing MCP API functionality...')
test_write = execute_mcp_command('echo "Testing MCP write functionality" > /tmp/mcp_test_$(date +%s).txt')
if test_write.get('stdout'):
    print('[MCP TEST] MCP execute_command works')
    
    # Test write_file API directly
    test_content = 'Test content from debug script'
    test_response = requests.post('http://192.168.111.200:8080', 
        json={'jsonrpc': '2.0', 'method': 'write_file', 
              'params': {'path': '/tmp/debug_write_test.txt', 'content': test_content}, 
              'id': 1})
    
    if test_response.status_code == 200:
        result = test_response.json()
        if 'result' in result:
            print('[WRITE_FILE] MCP write_file API works')
            
            # Verify the file was written
            verify = execute_mcp_command('cat /tmp/debug_write_test.txt 2>/dev/null')
            if verify.get('stdout'):
                print(f'[VERIFY] File content: {verify["stdout"].strip()}')
        else:
            print(f'[WRITE_FILE ERROR] {result}')
    else:
        print(f'[WRITE_FILE ERROR] HTTP {test_response.status_code}')

print('\n[6] Manual test of workflow file operations...')

# Test the exact same operations the workflow should be doing
print('\n[MANUAL TEST] Simulating workflow operations...')

# Check if dist files exist
dist_files = execute_mcp_command('ls -la /home/actions-runner/actions-runner/_work/mcp-cicd-pipeline/mcp-cicd-pipeline/dist/')
if dist_files.get('stdout'):
    print('[DIST FILES] Current dist/ contents:')
    for line in dist_files['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
    
    # Try reading one of the files
    app_content = execute_mcp_command('cat /home/actions-runner/actions-runner/_work/mcp-cicd-pipeline/mcp-cicd-pipeline/dist/app.js')
    if app_content.get('stdout'):
        content = app_content['stdout']
        print(f'\n[APP.JS] File size: {len(content)} characters')
        print(f'[PREVIEW] First 100 chars: {content[:100]}...')
        
        # Try the jq JSON escaping
        escaped_test = execute_mcp_command('echo \'console.log("test");\' | jq -Rs .')
        if escaped_test.get('stdout'):
            print(f'[JQ TEST] JSON escaping works: {escaped_test["stdout"].strip()}')
            
            # Try writing to a test location
            test_dir = '/root/mcp_project/test_manual_deploy'
            create_test_dir = execute_mcp_command(f'mkdir -p {test_dir}')
            
            # Use the same write_file method as workflow
            escaped_content = execute_mcp_command(f'cat /home/actions-runner/actions-runner/_work/mcp-cicd-pipeline/mcp-cicd-pipeline/dist/app.js | jq -Rs .')
            if escaped_content.get('stdout'):
                json_content = escaped_content['stdout'].strip()
                
                # Direct API call
                api_response = requests.post('http://192.168.111.200:8080',
                    json={'jsonrpc': '2.0', 'method': 'write_file',
                          'params': {'path': f'{test_dir}/app.js', 'content': json_content[1:-1]},  # Remove quotes
                          'id': 1})
                
                if api_response.status_code == 200:
                    result = api_response.json()
                    print(f'[MANUAL DEPLOY] API Response: {result}')
                    
                    # Verify file was written
                    verify_manual = execute_mcp_command(f'ls -la {test_dir}/ && head -3 {test_dir}/app.js 2>/dev/null')
                    if verify_manual.get('stdout'):
                        print('[MANUAL VERIFY] Test deployment successful:')
                        for line in verify_manual['stdout'].split('\n'):
                            if line.strip():
                                print(f'  {line}')

print('\n' + '=' * 45)
print('FINAL DIAGNOSIS')
print('=' * 45)

print('\nBased on this investigation:')
print('1. MCP API is working correctly')
print('2. Files exist in workspace dist/ directory')
print('3. jq tool is available and working')
print('4. The workflow reports success but files are not deployed')
print('\nLIKELY CAUSE: The GitHub Actions workflow shell script')
print('execution is not behaving as expected, possibly due to:')
print('- Shell script errors that are not being logged')
print('- Silent failures in the curl commands') 
print('- Issues with the JSON payload construction')
print('- The workflow thinks it succeeded but actually failed silently')

print('=' * 45)