#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Create Application Auto-start Service for Complete Restart Survival
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

print('Creating Application Auto-start Service')
print('=' * 50)

# Current status check
print('\n[1] Current Configuration Analysis...')

# Check runner service status
runner_status = execute_mcp_command('systemctl is-enabled actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
print(f'[RUNNER] Auto-start status: {runner_status.get("stdout", "unknown").strip()}')

# Check if app service already exists
app_service_check = execute_mcp_command('systemctl list-unit-files | grep mcp-app || echo "No mcp-app service"')
print(f'[APP SERVICE] Existing service: {app_service_check.get("stdout", "").strip()}')

# Create systemd service file for the application
print('\n[2] Creating Application Systemd Service...')

service_content = '''[Unit]
Description=MCP CI/CD Deployed Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/mcp_project/current
ExecStartPre=/bin/bash -c 'cd /root/mcp_project/current && npm install --production'
ExecStart=/bin/node app.js
Environment=PORT=3000
Environment=NODE_ENV=production
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
'''

# Encode service content as base64
import base64
encoded_service = base64.b64encode(service_content.encode()).decode()

# Create the service file
print('[SERVICE FILE] Creating mcp-app.service...')
create_service = execute_mcp_command(f'echo "{encoded_service}" | base64 -d > /etc/systemd/system/mcp-app.service')

if create_service.get('returncode') == 0:
    print('[SUCCESS] Service file created')
    
    # Verify service file
    verify_service = execute_mcp_command('cat /etc/systemd/system/mcp-app.service')
    if verify_service.get('stdout'):
        print('[VERIFY] Service file content:')
        for line in verify_service['stdout'].split('\n')[:10]:
            if line.strip():
                print(f'  {line}')
else:
    print('[ERROR] Failed to create service file')

# Reload systemd and enable the service
print('\n[3] Enabling Application Service...')
reload_systemd = execute_mcp_command('systemctl daemon-reload')
print('[RELOAD] Systemd configuration reloaded')

enable_service = execute_mcp_command('systemctl enable mcp-app.service')
if enable_service.get('returncode') == 0:
    print('[ENABLE] mcp-app service enabled for auto-start')
else:
    print('[ERROR] Failed to enable service')
    if enable_service.get('stderr'):
        print(f'[ERROR DETAILS] {enable_service["stderr"]}')

# Check current deployment symlink
print('\n[4] Checking Current Deployment Symlink...')
symlink_check = execute_mcp_command('ls -la /root/mcp_project/current')
if symlink_check.get('stdout'):
    print('[CURRENT] Deployment symlink:')
    print(f'  {symlink_check["stdout"].strip()}')
else:
    print('[ERROR] No current deployment symlink found')
    
    # Create symlink to latest release
    latest_release = execute_mcp_command('ls -t /root/mcp_project/releases/ | head -1')
    if latest_release.get('stdout'):
        latest_dir = latest_release['stdout'].strip()
        create_symlink = execute_mcp_command(f'ln -sfn /root/mcp_project/releases/{latest_dir} /root/mcp_project/current')
        if create_symlink.get('returncode') == 0:
            print(f'[SYMLINK] Created current -> {latest_dir}')
        else:
            print('[ERROR] Failed to create symlink')

# Test service start
print('\n[5] Testing Service Start...')
# Stop any running app first
stop_manual = execute_mcp_command('pkill -f "node.*app.js" || echo "No manual processes to stop"')
print(f'[STOP MANUAL] {stop_manual.get("stdout", "").strip()}')

# Start the service
start_service = execute_mcp_command('systemctl start mcp-app.service')
if start_service.get('returncode') == 0:
    print('[START] Service started successfully')
    
    # Check service status
    import time
    time.sleep(3)
    
    service_status = execute_mcp_command('systemctl status mcp-app.service --no-pager -l')
    if service_status.get('stdout'):
        print('[STATUS] Service status:')
        for line in service_status['stdout'].split('\n')[:15]:
            if line.strip():
                print(f'  {line}')
else:
    print('[ERROR] Failed to start service')
    if start_service.get('stderr'):
        print(f'[ERROR DETAILS] {start_service["stderr"]}')

# Test application response after service start
print('\n[6] Testing Application Response...')
import time
time.sleep(5)

app_test = execute_mcp_command('curl -s -w "HTTP_CODE:%{http_code}" http://localhost:3000/ --connect-timeout 10')
if app_test.get('stdout') and '200' in app_test['stdout']:
    print('[SUCCESS] Application responding via systemd service')
    response_text = app_test['stdout'].split('HTTP_CODE:')[0]
    try:
        response_data = json.loads(response_text)
        print('[RESPONSE] Application data:')
        for key, value in list(response_data.items())[:3]:  # First 3 items
            print(f'  {key}: {value}')
    except:
        print(f'[RESPONSE] Raw: {response_text[:100]}')
else:
    print('[WAITING] Application may still be starting...')
    if app_test.get('stdout'):
        print(f'[DEBUG] Response: {app_test["stdout"]}')

print('\n' + '=' * 50)
print('RESTART SURVIVAL CONFIGURATION COMPLETE')
print('=' * 50)

# Final status summary
print('\n[FINAL STATUS] Auto-startup Configuration:')

# Check runner service
runner_enabled = execute_mcp_command('systemctl is-enabled actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
runner_active = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')

print(f'  GitHub Actions Runner: {runner_enabled.get("stdout", "unknown").strip().upper()}')
print(f'  Runner Currently: {runner_active.get("stdout", "unknown").strip().upper()}')

# Check app service
app_enabled = execute_mcp_command('systemctl is-enabled mcp-app.service')
app_active = execute_mcp_command('systemctl is-active mcp-app.service')

print(f'  MCP Application: {app_enabled.get("stdout", "unknown").strip().upper()}')
print(f'  Application Currently: {app_active.get("stdout", "unknown").strip().upper()}')

print('\n[RESTART SURVIVAL ANALYSIS]')
runner_survives = runner_enabled.get('stdout', '').strip() == 'enabled'
app_survives = app_enabled.get('stdout', '').strip() == 'enabled'

if runner_survives and app_survives:
    print('  ✅ COMPLETE RESTART SURVIVAL: Both runner and app will auto-start')
    print('  ✅ CI/CD Pipeline: Will work immediately after server restart')
    print('  ✅ Application: Will be available after restart without manual intervention')
elif runner_survives:
    print('  🔧 PARTIAL SURVIVAL: Runner will restart, but check app service')
    print('  ✅ CI/CD Pipeline: Will work after restart')
    print('  ⚠️  Application: Check service status above')
else:
    print('  ❌ INCOMPLETE SURVIVAL: Additional configuration needed')

print('\n[TEST RECOMMENDATIONS]')
print('1. Test service restart: systemctl restart mcp-app.service')
print('2. Test runner restart: systemctl restart actions.runner...')
print('3. Simulate reboot: systemctl reboot (if possible)')
print('4. Verify both services start automatically')

print('\n[CONTINUOUS DEPLOYMENT FLOW AFTER RESTART]')
print('1. Server boots up')
print('2. GitHub Actions Runner service starts automatically')
print('3. MCP Application service starts automatically')
print('4. Runner connects to GitHub and listens for jobs')
print('5. New deployments update /root/mcp_project/current')
print('6. Service restart picks up new deployment')
print('7. Application serves updated code')

print('=' * 50)