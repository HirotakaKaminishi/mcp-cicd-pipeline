#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Monitor Unified CI/CD Workflow Execution
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

print('Unified CI/CD Workflow Monitoring')
print('=' * 60)
print(f'Start Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Commit: e7a3bc7 - Integrated CI/CD workflows')
print('Expected: Single "MCP Server CI/CD Pipeline" workflow')
print('=' * 60)

# Monitor for up to 5 minutes
max_wait = 300  # 5 minutes
start_time = time.time()
check_interval = 20  # Check every 20 seconds

deployment_found = False

while time.time() - start_time < max_wait:
    elapsed = int(time.time() - start_time)
    print(f'\n[{elapsed}s] Checking unified workflow status...')
    
    # Check runner activity
    runner_check = execute_mcp_command('ps aux | grep Runner | grep -v grep | head -3')
    if runner_check.get('stdout'):
        active_runners = runner_check['stdout'].strip().split('\n')
        print(f'[RUNNER] {len(active_runners)} processes active')
        for runner in active_runners:
            if 'Runner.Listener' in runner:
                print(f'  Listener: {runner[:80]}...')
            elif 'Runner.Worker' in runner:
                print(f'  Worker: {runner[:80]}...')
    else:
        print('[RUNNER] No runner processes found')
    
    # Check for new deployment with our commit
    deploy_check = execute_mcp_command('ls -lt /root/mcp_project/releases/ 2>/dev/null | head -3')
    if deploy_check.get('stdout'):
        print('[DEPLOY] Recent releases:')
        releases = []
        for line in deploy_check['stdout'].split('\n')[:3]:
            if line.strip() and not line.startswith('total'):
                print(f'  {line}')
                releases.append(line)
        
        # Check if latest release is recent (within last few minutes)
        if releases:
            # Look for releases created in the last 10 minutes
            recent_check = execute_mcp_command('find /root/mcp_project/releases -type d -mmin -10 2>/dev/null')
            if recent_check.get('stdout'):
                recent_dirs = [d for d in recent_check['stdout'].split('\n') if d.strip()]
                if recent_dirs:
                    print(f'[RECENT] {len(recent_dirs)} recent release directories found')
    
    # Check deployment log for our commit
    log_check = execute_mcp_command('grep "e7a3bc7" /root/mcp_project/deployment.log 2>/dev/null')
    if log_check.get('stdout'):
        print('[SUCCESS] Our commit found in deployment log:')
        print(f'  {log_check["stdout"].strip()}')
        deployment_found = True
        break
    
    # Check recent deployment log entries
    recent_log = execute_mcp_command('tail -3 /root/mcp_project/deployment.log 2>/dev/null')
    if recent_log.get('stdout'):
        print('[LOG] Recent deployment entries:')
        for line in recent_log['stdout'].strip().split('\n')[-2:]:
            if line.strip():
                print(f'  {line}')
    
    # Check if runner is currently working
    runner_status = execute_mcp_command('ps aux | grep -E "Runner.Worker|dotnet.*Runner" | grep -v grep')
    if runner_status.get('stdout'):
        print('[ACTIVE] Worker processes found - deployment likely in progress')
    else:
        print('[IDLE] No worker processes - runner idle')
    
    print(f'[WAIT] Continuing to monitor... ({elapsed}s/{max_wait}s)')
    time.sleep(check_interval)

print('\n' + '=' * 60)
print('Final Unified Workflow Status Check')
print('=' * 60)

# Final comprehensive check
if deployment_found:
    print('[RESULT] ✅ Unified workflow deployment SUCCESSFUL')
else:
    print('[RESULT] ❌ Deployment not detected yet')

# Check current deployment
current_check = execute_mcp_command('ls -la /root/mcp_project/current/ | head -5')
if current_check.get('stdout'):
    print('\n[CURRENT DEPLOYMENT]')
    for line in current_check['stdout'].split('\n')[:4]:
        if line.strip():
            print(f'  {line}')

# Check all deployment logs
all_logs = execute_mcp_command('tail -5 /root/mcp_project/deployment.log 2>/dev/null')
if all_logs.get('stdout'):
    print('\n[DEPLOYMENT HISTORY]')
    for line in all_logs['stdout'].split('\n')[-3:]:
        if line.strip():
            print(f'  {line}')

# Final commit verification
final_commit_check = execute_mcp_command('grep "e7a3bc7" /root/mcp_project/deployment.log 2>/dev/null')
if final_commit_check.get('stdout'):
    print(f'\n[COMMIT VERIFIED] ✅ Commit e7a3bc7 deployed successfully')
    print(f'  {final_commit_check["stdout"].strip()}')
else:
    print('\n[COMMIT STATUS] ❌ Commit e7a3bc7 not found in deployment log')

# Check if only one workflow is running
runner_processes = execute_mcp_command('ps aux | grep Runner | grep -v grep | wc -l')
if runner_processes.get('stdout'):
    process_count = int(runner_processes['stdout'].strip())
    if process_count <= 2:  # Listener + possibly one Worker
        print(f'\n[WORKFLOW COUNT] ✅ Single workflow running ({process_count} processes)')
    else:
        print(f'\n[WORKFLOW COUNT] ⚠️ Multiple processes detected ({process_count})')

print('\n' + '=' * 60)
print(f'Monitoring completed at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('\nKey Results:')
print(f'- Deployment Found: {"✅ Yes" if deployment_found else "❌ No"}')
print('- Expected: Single unified workflow instead of two separate workflows')
print('- GitHub Actions: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions')
print('=' * 60)