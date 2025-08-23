#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Monitor GitHub Actions Workflow Execution
"""

import requests
import json
import time
from datetime import datetime

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

print('GitHub Actions Workflow Monitoring')
print('=' * 50)
print(f'Start Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Commit: Fix ESLint error: Use single quotes in console.log')
print('=' * 50)

# Monitor for up to 5 minutes
max_wait = 300  # 5 minutes
start_time = time.time()
check_interval = 20  # Check every 20 seconds

while time.time() - start_time < max_wait:
    elapsed = int(time.time() - start_time)
    print(f'\n[{elapsed}s] Checking workflow status...')
    
    # Check runner activity
    runner_check = execute_mcp_command('ps aux | grep Runner | grep -v grep | head -3')
    if runner_check.get('stdout'):
        active_runners = runner_check['stdout'].strip().split('\n')
        print(f'[RUNNER] {len(active_runners)} processes active')
        for runner in active_runners:
            if 'Runner.Listener' in runner or 'Runner.Worker' in runner:
                print(f'  {runner[:100]}...')
    
    # Check for new deployment
    deploy_check = execute_mcp_command('ls -lt /root/mcp_project/releases/ 2>/dev/null | head -2')
    if deploy_check.get('stdout'):
        print('[DEPLOY] Recent releases:')
        for line in deploy_check['stdout'].split('\n')[:2]:
            if line.strip() and not line.startswith('total'):
                print(f'  {line}')
    
    # Check deployment log for recent activity
    log_check = execute_mcp_command('tail -3 /root/mcp_project/deployment.log 2>/dev/null')
    if log_check.get('stdout'):
        recent_logs = log_check['stdout'].strip().split('\n')
        print('[LOG] Recent deployment log:')
        for log_line in recent_logs[-2:]:
            if log_line.strip():
                print(f'  {log_line}')
    
    # Check if runner is currently running a job
    runner_status = execute_mcp_command('ps aux | grep -E "Runner.Worker|dotnet.*Runner" | grep -v grep')
    if runner_status.get('stdout'):
        print('[ACTIVE JOB] Worker processes found - job likely running')
    else:
        print('[IDLE] No worker processes - runner idle')
    
    # Look for successful deployment indicators
    success_check = execute_mcp_command('grep -i "successful" /root/mcp_project/deployment.log 2>/dev/null | tail -1')
    if success_check.get('stdout'):
        latest_success = success_check['stdout'].strip()
        if 'f593e53' in latest_success:  # Our commit hash
            print(f'[SUCCESS] Latest deployment found: {latest_success}')
            print('\nDeployment appears to be successful!')
            break
    
    print(f'[WAIT] Continuing to monitor... ({elapsed}s/{max_wait}s)')
    time.sleep(check_interval)

print('\n' + '=' * 50)
print('Final Status Check')
print('=' * 50)

# Final verification
final_deploy = execute_mcp_command('ls -la /root/mcp_project/current/')
if final_deploy.get('stdout'):
    print('[CURRENT] Current deployment:')
    for line in final_deploy['stdout'].split('\n')[:5]:
        if line.strip():
            print(f'  {line}')

final_log = execute_mcp_command('tail -5 /root/mcp_project/deployment.log 2>/dev/null')
if final_log.get('stdout'):
    print('[FINAL LOG] Last 5 deployment entries:')
    for line in final_log['stdout'].split('\n')[-3:]:
        if line.strip():
            print(f'  {line}')

# Check if our specific commit was deployed
commit_check = execute_mcp_command('grep "f593e53" /root/mcp_project/deployment.log 2>/dev/null')
if commit_check.get('stdout'):
    print(f'[COMMIT FOUND] Our commit f593e53 was deployed:')
    print(f'  {commit_check["stdout"].strip()}')
else:
    print('[COMMIT CHECK] Commit f593e53 not found in deployment log yet')

print('\n' + '=' * 50)
print(f'Monitoring completed at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Check GitHub Actions: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions')
print('=' * 50)