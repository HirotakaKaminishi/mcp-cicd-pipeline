#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Debug Deployment File Transfer Issue
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

print('Debugging Deployment File Transfer Issue')
print('=' * 50)

print('\n[ISSUE] Files are not being transferred to MCP server during deployment')
print('[CAUSE] Likely issue with workflow file transfer logic')

print('\n[WORKFLOW ANALYSIS] The deployment workflow tries to:')
print('1. Read files from dist/ directory in GitHub Actions runner')
print('2. Send file contents via MCP API write_file method')
print('3. Deploy to timestamped release directory')

print('\n[PROBLEM] Checking if dist/ directory has files during build...')

# Let's check what the runner working directory looks like
print('\n[DEBUG 1] Check if runner has access to files...')
runner_workspace = execute_mcp_command('ls -la /home/actions-runner/actions-runner/_work/mcp-cicd-pipeline/mcp-cicd-pipeline/ 2>/dev/null')
if runner_workspace.get('stdout'):
    print('[WORKSPACE] Runner workspace contents:')
    for line in runner_workspace['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check if dist directory exists in workspace
print('\n[DEBUG 2] Check dist directory in workspace...')
dist_check = execute_mcp_command('ls -la /home/actions-runner/actions-runner/_work/mcp-cicd-pipeline/mcp-cicd-pipeline/dist/ 2>/dev/null')
if dist_check.get('stdout'):
    print('[DIST] dist/ directory contents:')
    for line in dist_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[ERROR] dist/ directory not found in workspace!')

# Check if artifacts were downloaded correctly
print('\n[DEBUG 3] Check downloaded artifacts...')
artifacts_check = execute_mcp_command('find /home/actions-runner/actions-runner/_work/mcp-cicd-pipeline/mcp-cicd-pipeline/ -name "*.js" -o -name "*.json" 2>/dev/null')
if artifacts_check.get('stdout'):
    print('[ARTIFACTS] Found JavaScript/JSON files:')
    for line in artifacts_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check recent runner job logs for file operations
print('\n[DEBUG 4] Recent file operations in runner logs...')
file_ops = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --since "20 minutes ago" | grep -E "(Deploy.*files|cat.*dist|file.*content)" | tail -5')
if file_ops.get('stdout'):
    print('[FILE OPS] Recent file operations:')
    for line in file_ops['stdout'].split('\n'):
        if line.strip():
            print(f'  {line[:100]}...')

print('\n' + '=' * 50)
print('DIAGNOSIS AND FIX RECOMMENDATION')
print('=' * 50)

print('\n[DIAGNOSIS] The issue is likely one of the following:')
print('1. Build artifacts are not being created properly in the build step')
print('2. Artifacts are not being downloaded correctly in the deploy step')  
print('3. The workflow shell script cannot find files in dist/ directory')
print('4. File reading logic in the workflow is failing silently')

print('\n[FIX APPROACH] We should:')
print('1. Add debugging to the workflow to show dist/ contents')
print('2. Verify artifact upload/download is working')
print('3. Add error handling for file operations')
print('4. Test local build to ensure dist/ is populated')

print('\n[IMMEDIATE ACTION] Check if build step creates dist/ properly...')

# Check if the build actually creates files
print('\n[TEST BUILD] Simulating build step...')
sim_build = execute_mcp_command('cd /tmp && mkdir test_build && cd test_build && echo "console.log(\\"test\\");" > app.js && echo "{\\"name\\": \\"test\\"}" > package.json && ls -la')
if sim_build.get('stdout'):
    print('[SIM BUILD] Test build results:')
    for line in sim_build['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('\n[NEXT STEPS] To fix this issue:')
print('1. Add debug output to workflow showing dist/ contents before deployment')
print('2. Verify the build step actually populates dist/ directory')
print('3. Add error handling for file reading operations')
print('4. Consider alternative deployment method if file transfer continues failing')

print('=' * 50)