#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Monitor Runner Online Status and Queue Resolution
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

print('Monitoring Runner Online Status and Queue Resolution')
print('=' * 60)
print(f'Monitor Start: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Expected: Runner should go online, queue should resolve')
print('=' * 60)

# Monitor runner status for up to 3 minutes
monitor_duration = 180  # 3 minutes
check_interval = 20    # Check every 20 seconds
start_time = time.time()

print('\n[INITIAL STATUS] Current runner state...')
# Check initial runner status
initial_status = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep')
if initial_status.get('stdout'):
    print('[RUNNER] Process active:', initial_status['stdout'].strip()[:80])

initial_service = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
print(f'[SERVICE] Status: {initial_service.get("stdout", "unknown").strip()}')

print(f'\n[MONITORING] Checking every {check_interval} seconds for {monitor_duration//60} minutes...')

while time.time() - start_time < monitor_duration:
    elapsed = int(time.time() - start_time)
    print(f'\n[{elapsed}s] Status check...')
    
    # Check if runner is still active
    runner_check = execute_mcp_command('pgrep -f "Runner.Listener" > /dev/null && echo "ACTIVE" || echo "INACTIVE"')
    runner_status = runner_check.get('stdout', 'unknown').strip()
    print(f'[RUNNER] Process status: {runner_status}')
    
    # Check service status
    service_check = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
    service_status = service_check.get('stdout', 'unknown').strip()
    print(f'[SERVICE] Service status: {service_status}')
    
    # Check for recent service logs indicating activity
    recent_activity = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager --since "30 seconds ago" | grep -E "(Connected|Listening|Job|Running)" | tail -2')
    if recent_activity.get('stdout'):
        activity_lines = [line for line in recent_activity['stdout'].split('\n') if line.strip()]
        if activity_lines:
            print('[ACTIVITY] Recent runner activity:')
            for line in activity_lines[-1:]:
                print(f'  {line}')
    
    # Check if job queue has resolved (look for active job processing)
    job_activity = execute_mcp_command('ps aux | grep -E "Runner.Worker|dotnet.*Runner" | grep -v grep')
    if job_activity.get('stdout'):
        print('[JOB ACTIVE] Worker process detected - queue resolved!')
        print(f'  {job_activity["stdout"].strip()[:100]}')
        break
    else:
        print('[JOB STATUS] No active job processing')
    
    # Check for deployment activity (sign that job is running)
    deploy_activity = execute_mcp_command('find /root/mcp_project/releases -type d -mmin -2 2>/dev/null')
    if deploy_activity.get('stdout'):
        recent_dirs = [d for d in deploy_activity['stdout'].split('\n') if d.strip()]
        if recent_dirs:
            print(f'[DEPLOY] Recent deployment activity: {len(recent_dirs)} directories')
    
    # Every minute, show a summary
    if elapsed > 0 and elapsed % 60 == 0:
        print(f'\n[{elapsed//60} MINUTE SUMMARY]')
        summary_runner = execute_mcp_command('pgrep -f "Runner.Listener" | wc -l')
        summary_service = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
        print(f'  Runner processes: {summary_runner.get("stdout", "0").strip()}')
        print(f'  Service active: {summary_service.get("stdout", "unknown").strip()}')
    
    time.sleep(check_interval)

print('\n' + '=' * 60)
print('MONITORING COMPLETE')
print('=' * 60)

# Final comprehensive status
print('\n[FINAL STATUS] Complete system check...')

# Final runner status
final_runner = execute_mcp_command('ps aux | grep "Runner.Listener" | grep -v grep')
if final_runner.get('stdout'):
    print('[RUNNER] Final process status: ACTIVE')
    print(f'  PID: {final_runner["stdout"].split()[1]}')
else:
    print('[RUNNER] Final process status: INACTIVE')

# Final service status
final_service = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
print(f'[SERVICE] Final service status: {final_service.get("stdout", "unknown").strip()}')

# Check for recent connectivity messages
final_connectivity = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager --since "2 minutes ago" | grep -E "(Connected|Listening)" | tail -2')
if final_connectivity.get('stdout'):
    print('[CONNECTIVITY] Recent connection status:')
    for line in final_connectivity['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check if test deployment happened
test_deployment = execute_mcp_command('grep "41ac744" /root/mcp_project/deployment.log 2>/dev/null')
if test_deployment.get('stdout'):
    print('[SUCCESS] Test deployment found:')
    print(f'  {test_deployment["stdout"].strip()}')
else:
    print('[WAITING] Test deployment not found yet')

print('\n[INSTRUCTIONS] Next steps:')
if final_service.get('stdout', '').strip() == 'active' and final_runner.get('stdout'):
    print('1. Runner appears to be properly configured and running')
    print('2. Check GitHub Repository Runner page:')
    print('   https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
    print('3. Verify "mcp-server-runner" shows as "Online"')
    print('4. Cancel the queued workflow and re-run it')
    print('5. The workflow should execute immediately without queuing')
else:
    print('1. Runner may need additional troubleshooting')
    print('2. Consider re-registering the runner with a fresh token')

print('\nCurrent queued workflow:')
print('- Commit: 41ac744 (Final integration test)')
print('- Expected: Should execute once runner shows Online')
print('- Action: Cancel and re-run if still queued after 2 minutes')
print('=' * 60)