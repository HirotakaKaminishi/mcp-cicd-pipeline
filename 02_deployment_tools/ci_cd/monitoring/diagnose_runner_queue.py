#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Diagnose and Fix Persistent Runner Queue Issues
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

print('Diagnosing Persistent Runner Queue Issues')
print('=' * 50)

print('\n1. Current Runner Status Check...')
# Check service status
service_status = execute_mcp_command('systemctl status actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager')
if service_status.get('stdout'):
    print('[SERVICE] Current status:')
    for line in service_status['stdout'].split('\n')[:12]:
        if line.strip():
            print(f'  {line}')

print('\n2. Runner Process Analysis...')
# Check all runner processes
all_processes = execute_mcp_command('ps auxf | grep -E "Runner|actions-runner|runsvc" | grep -v grep')
if all_processes.get('stdout'):
    print('[PROCESSES] All runner-related processes:')
    for line in all_processes['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[ERROR] No runner processes found!')

print('\n3. GitHub Connection Test...')
# Test GitHub connectivity
github_test = execute_mcp_command('curl -s -w "HTTP_CODE:%{http_code}\n" https://api.github.com/zen')
if github_test.get('stdout'):
    print('[GITHUB] Connection test:', github_test['stdout'].strip())

print('\n4. Runner Configuration Check...')
# Check runner configuration files
config_files = execute_mcp_command('ls -la /home/actions-runner/actions-runner/.* 2>/dev/null | grep -E "\.(runner|credentials)$"')
if config_files.get('stdout'):
    print('[CONFIG] Configuration files:')
    print(config_files['stdout'])

print('\n5. Runner Service Logs (Last 10 entries)...')
# Get recent service logs
service_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager -n 10')
if service_logs.get('stdout'):
    print('[LOGS] Recent service activity:')
    for line in service_logs['stdout'].split('\n')[-8:]:
        if line.strip():
            print(f'  {line}')

print('\n6. Runner Directory Analysis...')
# Check runner directory structure
dir_check = execute_mcp_command('ls -la /home/actions-runner/actions-runner/ | grep -E "(bin|externals|\.sh$)"')
if dir_check.get('stdout'):
    print('[DIRECTORY] Key runner files:')
    for line in dir_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

print('\n' + '=' * 50)
print('RESOLVING QUEUE ISSUE')
print('=' * 50)

print('\n[FIX 1] Stopping and restarting runner service...')
# Stop service
stop_service = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh stop')
print('[STOP]', stop_service.get('stdout', 'Command executed')[:100])

# Wait a moment
time.sleep(3)

# Start service
start_service = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh start')
print('[START]', start_service.get('stdout', 'Command executed')[:100])

# Wait for startup
time.sleep(5)

print('\n[FIX 2] Verifying restart...')
# Check if service restarted properly
verify_restart = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep')
if verify_restart.get('stdout'):
    print('[SUCCESS] Runner.Listener is running:')
    print(f'  {verify_restart["stdout"].strip()}')
else:
    print('[ERROR] Runner.Listener not found after restart')
    
    print('\n[EMERGENCY] Attempting manual runner start...')
    # Kill any existing processes
    kill_processes = execute_mcp_command('pkill -f Runner && pkill -f runsvc')
    
    # Start manually
    manual_start = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo -u actions-runner nohup ./run.sh > runner.log 2>&1 &')
    print('[MANUAL] Manual start attempted')
    
    time.sleep(3)
    manual_verify = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep')
    if manual_verify.get('stdout'):
        print('[MANUAL SUCCESS] Manual start successful')
    else:
        print('[MANUAL FAIL] Manual start failed')

print('\n[FIX 3] Testing runner connectivity...')
# Test if runner can reach GitHub
connectivity_test = execute_mcp_command('curl -s https://api.github.com/user/repos -H "Authorization: Bearer dummy" 2>&1 | head -3')
if connectivity_test.get('stdout'):
    print('[CONNECTIVITY] GitHub API response:', connectivity_test['stdout'][:100])

print('\n[FIX 4] Final status verification...')
# Final comprehensive check
final_service = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
final_process = execute_mcp_command('pgrep -f "Runner.Listener" && echo "RUNNING" || echo "NOT_RUNNING"')

print(f'Service Active: {final_service.get("stdout", "unknown").strip()}')
print(f'Process Running: {final_process.get("stdout", "unknown").strip()}')

# Check recent service logs after restart
recent_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager --since "1 minute ago"')
if recent_logs.get('stdout'):
    print('\n[RECENT LOGS] Activity since restart:')
    for line in recent_logs['stdout'].split('\n')[-5:]:
        if line.strip() and ('Connected' in line or 'Listening' in line):
            print(f'  {line}')

print('\n' + '=' * 50)
print('RESOLUTION STATUS')
print('=' * 50)

# Final determination
is_service_active = final_service.get('stdout', '').strip() == 'active'
is_process_running = final_process.get('stdout', '').strip() == 'RUNNING'

if is_service_active and is_process_running:
    print('[RESULT] SUCCESS: Runner is now properly running')
    print('[ACTION] GitHub Actions queue should resolve automatically')
    print('[WAIT] Allow 1-2 minutes for GitHub to detect runner status')
else:
    print('[RESULT] ISSUE PERSISTS: Runner may need manual intervention')
    print('[ACTION] Check GitHub repository runner settings manually')

print('\nNext Steps:')
print('1. Check GitHub Repository Runner Page:')
print('   https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('2. Verify "mcp-server-runner" shows as "Online" status')
print('3. If still showing offline, runner may need re-registration')
print('4. Cancel and retry the queued workflow after 2 minutes')

print('\nIf runner still shows offline:')
print('- The runner may need to be re-registered with a new token')
print('- Check if firewall is blocking GitHub connections')
print('- Verify network connectivity to api.github.com')
print('=' * 50)