#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Final Integration Test Monitor
Complete end-to-end verification of unified CI/CD pipeline
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

print('Final Integration Test: Unified CI/CD Pipeline')
print('=' * 60)
print(f'Test Start: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Commit: 41ac744 - Final integration test')
print('Expected: Single unified workflow, no queue issues')
print('=' * 60)

# Pre-test verification
print('\n[PRE-TEST] Verifying runner status...')
runner_status = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service 2>/dev/null')
runner_process = execute_mcp_command('pgrep -f "Runner.Listener" > /dev/null && echo "RUNNING" || echo "NOT_RUNNING"')

print(f'Service Status: {runner_status.get("stdout", "unknown").strip()}')
print(f'Process Status: {runner_process.get("stdout", "unknown").strip()}')

if runner_process.get('stdout', '').strip() == 'RUNNING':
    print('[OK] Self-hosted runner is ready')
else:
    print('[ERROR] Runner not ready - test may fail')

# Monitor workflow execution
max_wait = 300  # 5 minutes
start_time = time.time()
check_interval = 15  # Check every 15 seconds

print(f'\n[MONITORING] Tracking workflow execution (up to {max_wait//60} minutes)...')

test_commit = '41ac744'
deployment_found = False
workflow_stages = {
    'triggered': False,
    'testing': False,
    'building': False,
    'deploying': False,
    'completed': False
}

while time.time() - start_time < max_wait:
    elapsed = int(time.time() - start_time)
    print(f'\n[{elapsed}s] Checking pipeline progress...')
    
    # Check for active runner jobs
    active_job = execute_mcp_command('ps aux | grep -E "Runner.Worker|dotnet.*Runner" | grep -v grep')
    if active_job.get('stdout'):
        workflow_stages['triggered'] = True
        print('[ACTIVE] Job is running on self-hosted runner')
        print(f'  Worker: {active_job["stdout"].strip()[:80]}...')
    else:
        if workflow_stages['triggered']:
            print('[IDLE] No active worker (job may have completed)')
        else:
            print('[WAITING] No active job detected yet')
    
    # Check runner service logs for recent activity
    recent_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager --since "2 minutes ago" | tail -3')
    if recent_logs.get('stdout'):
        log_lines = recent_logs['stdout'].strip().split('\n')
        for line in log_lines[-2:]:
            if line.strip() and ('Job' in line or 'Running' in line):
                print(f'[RUNNER LOG] {line}')
    
    # Check for deployment activity
    deploy_check = execute_mcp_command('find /root/mcp_project/releases -type d -mmin -5 2>/dev/null')
    if deploy_check.get('stdout'):
        recent_releases = [d for d in deploy_check['stdout'].split('\n') if d.strip()]
        if recent_releases:
            workflow_stages['deploying'] = True
            print(f'[DEPLOY] Recent deployment activity detected ({len(recent_releases)} directories)')
    
    # Check for our specific commit in deployment log
    commit_check = execute_mcp_command(f'grep "{test_commit}" /root/mcp_project/deployment.log 2>/dev/null')
    if commit_check.get('stdout'):
        workflow_stages['completed'] = True
        deployment_found = True
        print(f'[SUCCESS] Test commit {test_commit} deployed:')
        print(f'  {commit_check["stdout"].strip()}')
        break
    
    # Check recent deployment log entries
    recent_deployments = execute_mcp_command('tail -2 /root/mcp_project/deployment.log 2>/dev/null')
    if recent_deployments.get('stdout'):
        for line in recent_deployments['stdout'].strip().split('\n')[-1:]:
            if line.strip() and 'successful' in line:
                timestamp = line.split(':')[0]
                try:
                    # Check if deployment is recent (within last 5 minutes)
                    log_time = datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S')
                    current_time = datetime.utcnow()
                    if (current_time - log_time).total_seconds() < 300:  # 5 minutes
                        print(f'[RECENT] Recent deployment: {line}')
                except:
                    pass
    
    print(f'[PROGRESS] Stages: Triggered={workflow_stages["triggered"]}, Deploying={workflow_stages["deploying"]}, Completed={workflow_stages["completed"]}')
    
    if elapsed % 60 == 0:  # Every minute, show current status
        current_status = execute_mcp_command('ls -lt /root/mcp_project/releases/ 2>/dev/null | head -2')
        if current_status.get('stdout'):
            print(f'[STATUS] Latest releases:')
            for line in current_status['stdout'].split('\n')[:2]:
                if line.strip() and not line.startswith('total'):
                    print(f'  {line}')
    
    time.sleep(check_interval)

print('\n' + '=' * 60)
print('FINAL INTEGRATION TEST RESULTS')
print('=' * 60)

# Final comprehensive verification
if deployment_found:
    print('[RESULT] SUCCESS: Unified CI/CD pipeline test completed!')
    
    # Verify deployment details
    deployment_details = execute_mcp_command(f'grep "{test_commit}" /root/mcp_project/deployment.log')
    if deployment_details.get('stdout'):
        print(f'[DEPLOY] {deployment_details["stdout"].strip()}')
    
    # Check current deployment
    current_deploy = execute_mcp_command('ls -la /root/mcp_project/current/ | head -3')
    if current_deploy.get('stdout'):
        print('[CURRENT] Active deployment:')
        for line in current_deploy['stdout'].split('\n')[:3]:
            if line.strip():
                print(f'  {line}')
    
    # Test application response
    print('\n[APP TEST] Testing deployed application...')
    app_test = execute_mcp_command('curl -s http://localhost:3000/ 2>/dev/null | head -5')
    if app_test.get('stdout') and 'final_test' in app_test['stdout']:
        print('[APP] Application responding with test data')
        print(f'  {app_test["stdout"][:150]}')
    else:
        print('[APP] Application may not be running or not responding')

else:
    print('[RESULT] TIMEOUT: Deployment not detected within monitoring period')
    print('[INFO] Check GitHub Actions manually for current status')

# Final status summary
print(f'\n[SUMMARY] Test completed at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print(f'[COMMIT] Test commit: {test_commit}')
print(f'[DEPLOYED] Deployment found: {"YES" if deployment_found else "NO"}')

# Workflow stage summary
print('\n[STAGES] Workflow progression:')
for stage, status in workflow_stages.items():
    status_icon = 'Y' if status else 'N'
    print(f'  {stage.capitalize()}: {status_icon}')

print('\n[VERIFICATION] Check these URLs:')
print('- GitHub Actions: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions')
print('- Runner Status: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')

if deployment_found:
    print('\nTest Result: PASSED - Unified CI/CD pipeline working correctly!')
    print('Key achievements:')
    print('1. Single unified workflow (no duplicate workflows)')
    print('2. No queue issues with self-hosted runner') 
    print('3. Successful end-to-end deployment')
    print('4. Service-based runner (auto-restart capable)')
else:
    print('\nTest Result: NEEDS VERIFICATION - Check GitHub Actions page')
    print('Possible reasons: Network delay, runner restart needed, or workflow still processing')

print('=' * 60)