#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check Self-hosted Runner Status and Resolve Queue Issues
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

print('Self-hosted Runner Queue Issue Diagnosis')
print('=' * 50)

# Step 1: Check runner processes
print('\n1. Checking runner processes...')
runner_check = execute_mcp_command('ps aux | grep -E "Runner|actions-runner" | grep -v grep')
if runner_check.get('stdout'):
    print('[PROCESSES] Runner processes found:')
    for line in runner_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[ERROR] No runner processes found!')

# Step 2: Check runner service status
print('\n2. Checking runner service status...')
service_check = execute_mcp_command('systemctl status actions-runner.service 2>/dev/null || echo "Service not found"')
if service_check.get('stdout'):
    print('[SERVICE STATUS]')
    for line in service_check['stdout'].split('\n')[:10]:
        if line.strip():
            print(f'  {line}')

# Step 3: Check runner configuration
print('\n3. Checking runner configuration...')
config_check = execute_mcp_command('ls -la /home/actions-runner/actions-runner/.runner /home/actions-runner/actions-runner/.credentials 2>/dev/null')
if config_check.get('stdout'):
    print('[CONFIG FILES]')
    print(config_check['stdout'])
else:
    print('[ERROR] Runner configuration files missing!')

# Step 4: Check runner logs
print('\n4. Checking runner logs...')
log_check = execute_mcp_command('tail -20 /home/actions-runner/actions-runner/_diag/Runner_*.log 2>/dev/null | tail -10')
if log_check.get('stdout'):
    print('[RUNNER LOGS]')
    for line in log_check['stdout'].split('\n')[-5:]:
        if line.strip():
            print(f'  {line}')
else:
    print('[INFO] No runner diagnostic logs found')

# Step 5: Check if runner is listening
print('\n5. Checking runner listener status...')
listener_check = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep')
if listener_check.get('stdout'):
    print('[LISTENER] Runner.Listener is active:')
    print(f'  {listener_check["stdout"].strip()}')
else:
    print('[ERROR] Runner.Listener not found!')

# Step 6: Check network connectivity
print('\n6. Testing GitHub connectivity...')
github_check = execute_mcp_command('curl -s -I https://api.github.com | head -1')
if github_check.get('stdout'):
    print('[GITHUB] Connectivity test:')
    print(f'  {github_check["stdout"].strip()}')

# Step 7: Check runner directory
print('\n7. Checking runner directory...')
dir_check = execute_mcp_command('ls -la /home/actions-runner/actions-runner/ | grep -E "\.(sh|json)$" | head -5')
if dir_check.get('stdout'):
    print('[RUNNER DIR] Key files:')
    for line in dir_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('\n' + '=' * 50)
print('QUEUE ISSUE RESOLUTION STEPS')
print('=' * 50)

# Attempt to resolve queue issues
print('\n🔧 Attempting to resolve queue issues...')

# Step 1: Stop current runner
print('\n1. Stopping current runner...')
stop_result = execute_mcp_command('pkill -f "Runner.Listener" || echo "No listener to kill"')
print('[STOP]', stop_result.get('stdout', 'Command executed'))

# Step 2: Restart runner service
print('\n2. Restarting runner service...')
restart_service = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh stop && sleep 3 && sudo ./svc.sh start')
if restart_service.get('stdout'):
    print('[SERVICE RESTART]')
    print(restart_service['stdout'])

# Step 3: Check if service restart worked
print('\n3. Verifying service restart...')
verify_restart = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep')
if verify_restart.get('stdout'):
    print('[SUCCESS] Runner.Listener restarted:')
    print(f'  {verify_restart["stdout"].strip()}')
else:
    print('[MANUAL START] Service restart failed, trying manual start...')
    manual_start = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo -u actions-runner nohup ./run.sh > runner.log 2>&1 &')
    print('[MANUAL]', manual_start.get('stdout', 'Manual start attempted'))

# Step 4: Final status check
print('\n4. Final runner status...')
final_check = execute_mcp_command('ps aux | grep -E "Runner|actions-runner" | grep -v grep | head -3')
if final_check.get('stdout'):
    print('[FINAL STATUS] Runner processes:')
    for line in final_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[ERROR] Runner still not running after restart attempts')

print('\n' + '=' * 50)
print('RESOLUTION SUMMARY')
print('=' * 50)
print('If queue issue persists:')
print('1. Check GitHub Repository Settings:')
print('   https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('2. Verify runner shows as "Online"')
print('3. Cancel and re-run the queued workflow')
print('4. If still failing, the runner may need to be re-registered')
print('=' * 50)