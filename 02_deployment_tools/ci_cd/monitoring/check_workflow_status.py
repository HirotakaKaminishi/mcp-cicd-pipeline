#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check Current Workflow Status After Runner Fix
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

print('Workflow Status Check After Runner Service Fix')
print('=' * 55)
print(f'Check Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Expected: Queue should be resolved, workflow should execute')
print('=' * 55)

# Check 1: Runner service status
print('\n1. Runner service status...')
service_status = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh status | head -15')
if service_status.get('stdout'):
    print('[SERVICE] Current status:')
    for line in service_status['stdout'].split('\n')[:8]:
        if line.strip():
            print(f'  {line}')

# Check 2: Runner processes
print('\n2. Active runner processes...')
runner_processes = execute_mcp_command('ps aux | grep -E "Runner|runsvc" | grep -v grep')
if runner_processes.get('stdout'):
    print('[PROCESSES] Active:')
    for line in runner_processes['stdout'].split('\n'):
        if line.strip():
            print(f'  {line[:100]}')

# Check 3: Recent runner logs to see if jobs are being processed
print('\n3. Recent runner activity...')
recent_activity = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager -n 5 2>/dev/null')
if recent_activity.get('stdout'):
    print('[ACTIVITY] Recent service logs:')
    for line in recent_activity['stdout'].split('\n')[-4:]:
        if line.strip():
            print(f'  {line[:120]}')

# Check 4: Look for deployment activity
print('\n4. Checking for deployment activity...')
deploy_activity = execute_mcp_command('ls -lt /root/mcp_project/releases/ 2>/dev/null | head -3')
if deploy_activity.get('stdout'):
    print('[RELEASES] Recent releases:')
    for line in deploy_activity['stdout'].split('\n')[:3]:
        if line.strip() and not line.startswith('total'):
            print(f'  {line}')

# Check 5: Look for our specific commit
print('\n5. Checking for our unified workflow deployment...')
commit_check = execute_mcp_command('grep "e7a3bc7" /root/mcp_project/deployment.log 2>/dev/null')
if commit_check.get('stdout'):
    print('[SUCCESS] Unified workflow deployment found:')
    print(f'  {commit_check["stdout"].strip()}')
else:
    print('[WAITING] Unified workflow deployment not found yet')

# Check 6: Monitor for active job processing
print('\n6. Monitoring for active job processing (30 seconds)...')
for i in range(6):  # Check 6 times, every 5 seconds
    time.sleep(5)
    worker_check = execute_mcp_command('ps aux | grep -E "Runner.Worker|dotnet.*Runner" | grep -v grep')
    if worker_check.get('stdout'):
        print(f'[{i*5+5}s] JOB ACTIVE: Worker process found')
        print(f'  {worker_check["stdout"].strip()[:100]}')
        break
    else:
        print(f'[{i*5+5}s] IDLE: No active job processing')

# Check 7: Final deployment status
print('\n7. Final deployment check...')
final_log = execute_mcp_command('tail -3 /root/mcp_project/deployment.log 2>/dev/null')
if final_log.get('stdout'):
    print('[FINAL LOGS] Recent deployments:')
    for line in final_log['stdout'].split('\n')[-2:]:
        if line.strip():
            print(f'  {line}')

# Check 8: Current deployment symlink
print('\n8. Current deployment status...')
current_deployment = execute_mcp_command('ls -la /root/mcp_project/current/ | head -3')
if current_deployment.get('stdout'):
    print('[CURRENT] Active deployment:')
    for line in current_deployment['stdout'].split('\n')[:3]:
        if line.strip():
            print(f'  {line}')

print('\n' + '=' * 55)
print('SUMMARY')
print('=' * 55)

# Summary check
runner_running = execute_mcp_command('pgrep -f "Runner.Listener" > /dev/null && echo "YES" || echo "NO"')
service_active = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service 2>/dev/null || echo "inactive"')

print(f'Runner Process: {runner_running.get("stdout", "unknown").strip()}')
print(f'Service Status: {service_active.get("stdout", "unknown").strip()}')

commit_deployed = execute_mcp_command('grep -q "e7a3bc7" /root/mcp_project/deployment.log 2>/dev/null && echo "YES" || echo "NO"')
print(f'Unified Workflow Deployed: {commit_deployed.get("stdout", "unknown").strip()}')

print('\nActions to take:')
if commit_deployed.get('stdout', '').strip() == 'YES':
    print('✅ SUCCESS: Unified workflow has been deployed successfully!')
    print('   - Queue issue resolved')
    print('   - Single workflow is now active')
    print('   - Check GitHub Actions page to confirm')
else:
    print('⏳ WAITING: Workflow may still be processing')
    print('   - Runner is now properly configured as service')
    print('   - Queue should be resolved')
    print('   - Monitor GitHub Actions page for progress')

print('\nGitHub Actions: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions')
print('Runner Settings: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('=' * 55)