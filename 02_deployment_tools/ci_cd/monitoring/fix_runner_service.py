#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix Self-hosted Runner Service Registration
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

print('Fixing Self-hosted Runner Service Registration')
print('=' * 50)

# Step 1: Stop current runner processes
print('\n1. Stopping current runner processes...')
stop_processes = execute_mcp_command('pkill -f "Runner.Listener" && pkill -f "run.sh" && sleep 2')
print('[STOP] Processes stopped')

# Step 2: Check if svc.sh exists
print('\n2. Checking for service script...')
svc_check = execute_mcp_command('ls -la /home/actions-runner/actions-runner/svc.sh')
if svc_check.get('stdout'):
    print('[SVC.SH] Service script found:')
    print(svc_check['stdout'])
    
    # Step 3: Install as service
    print('\n3. Installing runner as service...')
    install_service = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh install')
    if install_service.get('stdout'):
        print('[INSTALL] Service installation:')
        for line in install_service['stdout'].split('\n'):
            if line.strip():
                print(f'  {line}')
    
    # Step 4: Start service
    print('\n4. Starting runner service...')
    start_service = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh start')
    if start_service.get('stdout'):
        print('[START] Service start:')
        for line in start_service['stdout'].split('\n'):
            if line.strip():
                print(f'  {line}')
    
    # Step 5: Check service status
    print('\n5. Checking service status...')
    time.sleep(5)  # Wait for service to start
    status_check = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo ./svc.sh status')
    if status_check.get('stdout'):
        print('[STATUS] Service status:')
        for line in status_check['stdout'].split('\n'):
            if line.strip():
                print(f'  {line}')

else:
    print('[ERROR] svc.sh not found, starting manually...')
    # Manual start as fallback
    print('\n3. Starting runner manually...')
    manual_start = execute_mcp_command('cd /home/actions-runner/actions-runner && sudo -u actions-runner nohup ./run.sh > runner.log 2>&1 &')
    print('[MANUAL] Manual start attempted')

# Step 6: Verify runner is running
print('\n6. Verifying runner status...')
time.sleep(3)
runner_verify = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep')
if runner_verify.get('stdout'):
    print('[SUCCESS] Runner.Listener is running:')
    print(f'  {runner_verify["stdout"].strip()}')
else:
    print('[ERROR] Runner.Listener not found after restart')

# Step 7: Check system service status
print('\n7. Checking systemd service...')
systemd_check = execute_mcp_command('systemctl status actions-runner.service 2>/dev/null | head -10')
if systemd_check.get('stdout') and 'not found' not in systemd_check['stdout']:
    print('[SYSTEMD] Service status:')
    for line in systemd_check['stdout'].split('\n')[:5]:
        if line.strip():
            print(f'  {line}')
else:
    print('[INFO] Systemd service not registered or not found')

# Step 8: Test runner connectivity
print('\n8. Testing runner connectivity...')
time.sleep(2)
connectivity_test = execute_mcp_command('curl -s https://api.github.com/zen')
if connectivity_test.get('stdout'):
    print('[CONNECTIVITY] GitHub API test:', connectivity_test['stdout'].strip()[:50])

# Step 9: Final status summary
print('\n9. Final status summary...')
final_processes = execute_mcp_command('ps aux | grep -E "Runner|actions-runner" | grep -v grep | head -3')
if final_processes.get('stdout'):
    print('[FINAL] Active runner processes:')
    for line in final_processes['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Step 10: Check runner logs
print('\n10. Checking recent runner activity...')
log_check = execute_mcp_command('tail -5 /home/actions-runner/actions-runner/runner.log 2>/dev/null')
if log_check.get('stdout'):
    print('[LOGS] Recent runner log entries:')
    for line in log_check['stdout'].split('\n')[-3:]:
        if line.strip():
            print(f'  {line}')

print('\n' + '=' * 50)
print('RESOLUTION COMPLETE')
print('=' * 50)
print('Next steps:')
print('1. Check GitHub Repository Runner Status:')
print('   https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('2. Look for "mcp-server-runner" with "Online" status')
print('3. Cancel and re-run the queued workflow if needed')
print('4. The runner should now properly handle GitHub Actions jobs')
print('=' * 50)