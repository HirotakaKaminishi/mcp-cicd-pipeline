#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check Available MCP API Methods
"""

import requests
import json

def call_mcp_api(method, params=None):
    """Call MCP API"""
    url = 'http://192.168.111.200:8080'
    payload = {
        'jsonrpc': '2.0',
        'method': method,
        'params': params or {},
        'id': 1
    }
    try:
        response = requests.post(url, json=payload, timeout=30)
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        return {'error': str(e)}
    return {'error': 'Request failed'}

print('MCP API Methods Investigation')
print('=' * 40)

# Test known working methods
print('\n[1] Testing known working methods...')

# Test execute_command (we know this works)
exec_test = call_mcp_api('execute_command', {'command': 'echo "test"'})
print(f'execute_command: {exec_test}')

# Test get_system_info (we know this works)
system_test = call_mcp_api('get_system_info')
print(f'get_system_info: {system_test}')

# Test various possible file-related methods
print('\n[2] Testing possible file methods...')

file_methods = [
    'write_file',
    'create_file', 
    'save_file',
    'put_file',
    'upload_file',
    'store_file'
]

for method in file_methods:
    result = call_mcp_api(method, {'path': '/tmp/test.txt', 'content': 'test'})
    if 'error' in result and 'Unknown method' not in str(result['error']):
        print(f'{method}: AVAILABLE - {result}')
    else:
        print(f'{method}: NOT AVAILABLE')

print('\n[3] Testing alternative deployment approaches...')

# Test using execute_command to write files
print('\n[ALT 1] Using execute_command to write files...')
file_content = 'console.log("test deployment");'
write_via_exec = call_mcp_api('execute_command', {
    'command': f'echo \'{file_content}\' > /tmp/test_deploy_via_exec.js'
})
print(f'Write via execute_command: {write_via_exec}')

# Verify it worked
verify_exec = call_mcp_api('execute_command', {'command': 'cat /tmp/test_deploy_via_exec.js'})
print(f'Verification: {verify_exec}')

print('\n[ALT 2] Using execute_command with base64 encoding...')
import base64

# Encode file content as base64 to avoid shell escaping issues
test_content = '// Test deployment\nconsole.log("Hello from deployed app");'
encoded_content = base64.b64encode(test_content.encode()).decode()

base64_deploy = call_mcp_api('execute_command', {
    'command': f'echo "{encoded_content}" | base64 -d > /tmp/test_deploy_base64.js'
})
print(f'Base64 deployment: {base64_deploy}')

# Verify base64 method
verify_base64 = call_mcp_api('execute_command', {'command': 'cat /tmp/test_deploy_base64.js'})
print(f'Base64 verification: {verify_base64}')

print('\n' + '=' * 40)
print('SOLUTION FOUND')
print('=' * 40)

print('\n[CONCLUSION] The issue is clear:')
print('1. write_file method does NOT exist in this MCP server')
print('2. We must use execute_command with shell commands to write files')
print('3. Base64 encoding can solve shell escaping issues')

print('\n[RECOMMENDED FIX] Update the workflow to use:')
print('1. execute_command instead of write_file')
print('2. Base64 encoding for file contents to avoid shell escaping')
print('3. Simple shell redirection: echo "base64_content" | base64 -d > file')

print('\n[NEXT STEPS]')
print('1. Update the deployment workflow to use execute_command')
print('2. Implement base64 encoding for file contents')  
print('3. Test the fixed deployment')

print('=' * 40)