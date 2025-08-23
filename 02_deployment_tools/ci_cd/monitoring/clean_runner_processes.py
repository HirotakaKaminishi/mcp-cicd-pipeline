#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Clean up duplicate runner processes and ensure single runner
"""

import requests
import json
import time

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

print('Cleaning Up Duplicate Runner Processes')
print('=' * 45)

# Step 1: Show current processes
print('\n1. Current runner processes:')
current_processes = execute_mcp_command('ps aux | grep -E "Runner|runsvc" | grep -v grep')
if current_processes.get('stdout'):
    processes = current_processes['stdout'].strip().split('\n')
    print(f'[FOUND] {len(processes)} runner-related processes:')
    for i, process in enumerate(processes, 1):
        print(f'  {i}. {process[:100]}')

# Step 2: Stop all runner processes cleanly
print('\n2. Stopping all runner processes...')
stop_service = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh stop')
print('[STOP SERVICE]', 'Command executed')

# Wait for clean shutdown
time.sleep(3)

# Kill any remaining processes
print('\n3. Killing any remaining processes...')
kill_runners = execute_mcp_command('pkill -f "Runner" && pkill -f "runsvc"')
print('[KILL]', 'Kill commands executed')

time.sleep(2)

# Verify processes are gone
verify_clean = execute_mcp_command('ps aux | grep -E "Runner|runsvc" | grep -v grep')
if verify_clean.get('stdout'):
    print('[WARNING] Some processes still running:')
    for line in verify_clean['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[SUCCESS] All runner processes stopped')

# Step 4: Start single clean service
print('\n4. Starting single clean runner service...')
start_clean = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh start')
if start_clean.get('stdout'):
    print('[START] Service start output:')
    for line in start_clean['stdout'].split('\n')[:8]:
        if line.strip():
            print(f'  {line}')

# Wait for startup
print('\n5. Waiting for service startup...')
time.sleep(5)

# Verify single process
verify_single = execute_mcp_command('ps aux | grep -E "Runner|runsvc" | grep -v grep')
if verify_single.get('stdout'):
    processes = verify_single['stdout'].strip().split('\n')
    print(f'[VERIFICATION] {len(processes)} processes after restart:')
    for i, process in enumerate(processes, 1):
        print(f'  {i}. {process[:100]}')
    
    # Count actual runner listeners
    listener_count = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep | wc -l')
    if listener_count.get('stdout'):
        count = int(listener_count['stdout'].strip())
        if count == 1:
            print(f'[SUCCESS] Exactly 1 Runner.Listener process (optimal)')
        elif count > 1:
            print(f'[WARNING] {count} Runner.Listener processes (may cause conflicts)')
        else:
            print(f'[ERROR] No Runner.Listener processes found')

# Step 6: Check service status
print('\n6. Final service status check...')
service_status = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
print(f'Service Status: {service_status.get("stdout", "unknown").strip()}')

# Step 7: Check recent logs for connectivity
print('\n7. Checking connectivity logs...')
recent_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager --since "30 seconds ago"')
if recent_logs.get('stdout'):
    log_lines = recent_logs['stdout'].split('\n')
    for line in log_lines[-6:]:
        if 'Connected' in line or 'Listening' in line:
            print(f'[LOG] {line}')

# Step 8: Test runner readiness
print('\n8. Testing runner readiness...')
time.sleep(3)

ready_check = execute_mcp_command('pgrep -f "Runner.Listener" > /dev/null && echo "READY" || echo "NOT_READY"')
print(f'Runner Ready: {ready_check.get("stdout", "unknown").strip()}')

if ready_check.get('stdout', '').strip() == 'READY':
    print('\n[SUCCESS] Runner cleanup complete!')
    print('Actions to take:')
    print('1. Wait 1-2 minutes for GitHub to recognize runner status')
    print('2. Check GitHub runner page: should show "Online"')
    print('3. Cancel the queued job and re-run it')
    print('4. The job should now execute immediately without queuing')
else:
    print('\n[ERROR] Runner still not ready after cleanup')
    print('May need manual runner re-registration')

print('\n' + '=' * 45)
print('GitHub Repository Runner Settings:')
print('https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('Expected: "mcp-server-runner" showing "Online" status')
print('=' * 45)