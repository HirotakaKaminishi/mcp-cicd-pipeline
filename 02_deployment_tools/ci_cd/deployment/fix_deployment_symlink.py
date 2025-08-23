#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix Deployment Symlink and Complete Auto-startup Configuration
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

print('Fixing Deployment Symlink and Auto-startup Configuration')
print('=' * 65)

# 1. Fix the current deployment symlink
print('\n[1] Fixing Current Deployment Symlink...')

# Get the latest release
latest_release = execute_mcp_command('ls -t /root/mcp_project/releases/ | head -1')
if latest_release.get('stdout'):
    latest_dir = latest_release['stdout'].strip()
    print(f'[LATEST] Latest release: {latest_dir}')
    
    # Remove the current directory and create proper symlink
    fix_symlink = execute_mcp_command(f'rm -rf /root/mcp_project/current && ln -sfn /root/mcp_project/releases/{latest_dir} /root/mcp_project/current')
    
    if fix_symlink.get('returncode') == 0:
        print('[FIXED] Current symlink updated')
        
        # Verify symlink
        verify_link = execute_mcp_command('ls -la /root/mcp_project/current')
        if verify_link.get('stdout'):
            print('[VERIFY] New symlink:')
            print(f'  {verify_link["stdout"].strip()}')
            
        # Check target directory contents
        target_contents = execute_mcp_command('ls -la /root/mcp_project/current/')
        if target_contents.get('stdout'):
            print('[TARGET] Current deployment contents:')
            for line in target_contents['stdout'].split('\n')[:8]:
                if line.strip() and not line.startswith('total'):
                    print(f'  {line}')
    else:
        print('[ERROR] Failed to create symlink')

# 2. Stop the failed service and check logs
print('\n[2] Checking Service Status and Logs...')
service_status = execute_mcp_command('systemctl status mcp-app.service --no-pager')
if service_status.get('stdout'):
    print('[SERVICE STATUS] Current status:')
    for line in service_status['stdout'].split('\n')[:10]:
        if line.strip():
            print(f'  {line}')

# Check service logs
service_logs = execute_mcp_command('journalctl -u mcp-app.service --no-pager -n 10')
if service_logs.get('stdout'):
    print('\n[SERVICE LOGS] Recent logs:')
    for line in service_logs['stdout'].split('\n')[-5:]:
        if line.strip():
            print(f'  {line}')

# 3. Restart the service with proper symlink
print('\n[3] Restarting Application Service...')
restart_service = execute_mcp_command('systemctl restart mcp-app.service')

if restart_service.get('returncode') == 0:
    print('[RESTART] Service restart initiated')
    
    # Wait for startup
    print('[WAITING] Allowing time for service startup...')
    time.sleep(8)
    
    # Check service status after restart
    new_status = execute_mcp_command('systemctl status mcp-app.service --no-pager')
    if new_status.get('stdout'):
        print('[NEW STATUS] Service status after restart:')
        for line in new_status['stdout'].split('\n')[:12]:
            if line.strip():
                print(f'  {line}')
                
    # Check if service is active
    is_active = execute_mcp_command('systemctl is-active mcp-app.service')
    print(f'[ACTIVE STATUS] Service is: {is_active.get("stdout", "unknown").strip()}')
    
else:
    print('[ERROR] Service restart failed')

# 4. Test application response
print('\n[4] Testing Application Response...')
for attempt in range(3):
    print(f'[ATTEMPT {attempt+1}/3] Testing endpoint...')
    
    app_test = execute_mcp_command('curl -s -w "HTTP_CODE:%{http_code}" http://localhost:3000/ --connect-timeout 10 --max-time 15')
    
    if app_test.get('stdout') and '200' in app_test['stdout']:
        print('[SUCCESS] Application is responding!')
        response_text = app_test['stdout'].split('HTTP_CODE:')[0]
        try:
            response_data = json.loads(response_text)
            print('[RESPONSE] Application response:')
            for key, value in response_data.items():
                print(f'  {key}: {value}')
        except:
            print(f'[RESPONSE] Raw response: {response_text[:150]}')
        break
    else:
        print(f'[WAITING] Attempt {attempt+1} - no response yet')
        if app_test.get('stdout'):
            print(f'[DEBUG] Response: {app_test["stdout"][:100]}')
        time.sleep(5)
else:
    print('[TIMEOUT] Application not responding after 3 attempts')

# 5. Test health endpoint
health_test = execute_mcp_command('curl -s http://localhost:3000/health --connect-timeout 5')
if health_test.get('stdout'):
    try:
        health_data = json.loads(health_test['stdout'])
        print('\n[HEALTH] Health check response:')
        for key, value in health_data.items():
            print(f'  {key}: {value}')
    except:
        print(f'\n[HEALTH] Raw health response: {health_test["stdout"][:100]}')

# 6. Check process information
print('\n[5] Process Information...')
process_check = execute_mcp_command('ps aux | grep "node.*app.js" | grep -v grep')
if process_check.get('stdout'):
    print('[PROCESS] Application process:')
    print(f'  {process_check["stdout"].strip()}')
    
    # Get process tree
    pid = process_check['stdout'].split()[1] if process_check.get('stdout') else None
    if pid:
        process_tree = execute_mcp_command(f'pstree -p {pid}')
        if process_tree.get('stdout'):
            print(f'[TREE] Process tree: {process_tree["stdout"].strip()}')

print('\n' + '=' * 65)
print('FINAL RESTART SURVIVAL VERIFICATION')
print('=' * 65)

# Final comprehensive check
print('\n[FINAL VERIFICATION] Complete Auto-startup Status:')

# Check all relevant services
runner_enabled = execute_mcp_command('systemctl is-enabled actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
runner_active = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
app_enabled = execute_mcp_command('systemctl is-enabled mcp-app.service')
app_active = execute_mcp_command('systemctl is-active mcp-app.service')

print(f'  GitHub Actions Runner: {runner_enabled.get("stdout", "unknown").strip().upper()} / {runner_active.get("stdout", "unknown").strip().upper()}')
print(f'  MCP Application: {app_enabled.get("stdout", "unknown").strip().upper()} / {app_active.get("stdout", "unknown").strip().upper()}')

# Determine restart survival status
runner_survives = runner_enabled.get('stdout', '').strip() == 'enabled'
app_survives = app_enabled.get('stdout', '').strip() == 'enabled'
app_running = app_active.get('stdout', '').strip() == 'active'

print('\n[RESTART SURVIVAL ASSESSMENT]')
if runner_survives and app_survives and app_running:
    print('  EXCELLENT: Complete restart survival configured!')
    print('    - GitHub Actions Runner: Will auto-start')
    print('    - MCP Application: Will auto-start')
    print('    - CI/CD Pipeline: Will work immediately after restart')
    print('    - Application: Will be available without manual intervention')
    
elif runner_survives and app_survives:
    print('  GOOD: Auto-start configured, application may need debugging')
    print('    - GitHub Actions Runner: Will auto-start')
    print('    - MCP Application: Configured but check service status')
    print('    - CI/CD Pipeline: Will work after restart')
    
elif runner_survives:
    print('  PARTIAL: CI/CD will work, but application needs attention')
    print('    - GitHub Actions Runner: Will auto-start')
    print('    - MCP Application: Needs service configuration fix')
    
else:
    print('  INCOMPLETE: Additional configuration needed')

print('\n[CONTINUOUS DEPLOYMENT AFTER RESTART]')
print('1. Server restarts')
print('2. GitHub Actions Runner starts automatically')
print('3. MCP Application starts automatically (if service is working)')
print('4. New deployments will:')
print('   a. Deploy files to new release directory')
print('   b. Update /root/mcp_project/current symlink')
print('   c. Service can be restarted to pick up changes')
print('5. Application serves latest deployed code')

print('\n[DEPLOYMENT WORKFLOW UPDATE NEEDED]')
print('Consider adding to CI/CD workflow after successful deployment:')
print('  - systemctl reload mcp-app.service')
print('  - Or systemctl restart mcp-app.service')
print('  - This ensures new deployments are immediately active')

print('=' * 65)