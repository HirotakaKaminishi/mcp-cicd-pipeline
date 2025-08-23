#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check Auto-startup Configuration for Continuous Deployment
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

print('MCP Server Auto-startup Configuration Check')
print('=' * 60)
print('Checking if continuous deployment survives server restarts')
print('=' * 60)

# 1. Check GitHub Actions Runner service status and configuration
print('\n[1] GitHub Actions Runner Service Configuration...')
runner_service_status = execute_mcp_command('systemctl status actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager')

if runner_service_status.get('stdout'):
    print('[RUNNER SERVICE] Current status:')
    for line in runner_service_status['stdout'].split('\n')[:15]:  # First 15 lines
        if line.strip():
            print(f'  {line}')

# Check if runner service is enabled for auto-start
print('\n[2] Runner Auto-start Configuration...')
runner_enabled = execute_mcp_command('systemctl is-enabled actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
print(f'[RUNNER AUTO-START] Service enabled status: {runner_enabled.get("stdout", "unknown").strip()}')

# Check service file configuration
runner_service_file = execute_mcp_command('cat /etc/systemd/system/actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service 2>/dev/null')
if runner_service_file.get('stdout'):
    print('\n[RUNNER SERVICE FILE] Service configuration:')
    for line in runner_service_file['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# 2. Check if there's an application auto-start service
print('\n[3] Application Auto-start Service Check...')
app_service_check = execute_mcp_command('systemctl list-unit-files | grep -E "(mcp.*app|node.*app)" || echo "No application service found"')
print(f'[APP SERVICE] Application service status: {app_service_check.get("stdout", "Not found").strip()}')

# Check for any custom startup scripts
print('\n[4] Custom Startup Scripts Check...')
startup_scripts = execute_mcp_command('find /etc/rc.d/ /etc/init.d/ /root/ -name "*mcp*" -o -name "*app*" -o -name "*deploy*" 2>/dev/null | head -10')
if startup_scripts.get('stdout'):
    print('[STARTUP SCRIPTS] Found startup scripts:')
    for line in startup_scripts['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[STARTUP SCRIPTS] No custom startup scripts found')

# 5. Check current application process and how it's started
print('\n[5] Current Application Process Analysis...')
app_process = execute_mcp_command('ps aux | grep "node.*app.js" | grep -v grep')
if app_process.get('stdout'):
    print('[APP PROCESS] Current running application:')
    print(f'  {app_process["stdout"].strip()}')
    
    # Get process details
    pid = app_process['stdout'].split()[1] if app_process.get('stdout') else None
    if pid:
        process_details = execute_mcp_command(f'ps -p {pid} -o pid,ppid,cmd,etime --no-headers')
        if process_details.get('stdout'):
            print('[PROCESS DETAILS] Application process info:')
            print(f'  {process_details["stdout"].strip()}')
else:
    print('[APP PROCESS] No application process currently running')

# 6. Check system boot configuration
print('\n[6] System Boot and Auto-start Configuration...')
boot_config = execute_mcp_command('systemctl list-unit-files --type=service --state=enabled | grep -E "(runner|mcp|node)" || echo "No relevant services enabled"')
print('[BOOT CONFIG] Enabled services at boot:')
print(f'  {boot_config.get("stdout", "None found").strip()}')

# 7. Check deployment directory permissions and structure
print('\n[7] Deployment Directory Structure...')
deploy_structure = execute_mcp_command('ls -la /root/mcp_project/ | head -10')
if deploy_structure.get('stdout'):
    print('[DEPLOY STRUCTURE] Project directory:')
    for line in deploy_structure['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check current symlink
current_symlink = execute_mcp_command('ls -la /root/mcp_project/current')
if current_symlink.get('stdout'):
    print('\n[CURRENT DEPLOY] Active deployment symlink:')
    print(f'  {current_symlink["stdout"].strip()}')

print('\n' + '=' * 60)
print('AUTO-STARTUP ANALYSIS AND RECOMMENDATIONS')
print('=' * 60)

# Analysis
runner_is_enabled = runner_enabled.get('stdout', '').strip() == 'enabled'
runner_is_active = 'active (running)' in runner_service_status.get('stdout', '')
app_is_running = bool(app_process.get('stdout'))

print('\n[CURRENT STATUS]')
print(f'  GitHub Actions Runner Service: {"ENABLED" if runner_is_enabled else "NOT ENABLED"} at boot')
print(f'  Runner Currently Active: {"YES" if runner_is_active else "NO"}')
print(f'  Application Currently Running: {"YES" if app_is_running else "NO"}')

print('\n[RESTART SURVIVAL ANALYSIS]')
if runner_is_enabled and runner_is_active:
    print('  ✅ GitHub Actions Runner: WILL SURVIVE RESTART')
    print('     - Service is enabled and will auto-start')
    print('     - CI/CD pipeline will continue working after reboot')
else:
    print('  ⚠️  GitHub Actions Runner: MAY NOT SURVIVE RESTART')
    if not runner_is_enabled:
        print('     - Service is not enabled for auto-start')
    if not runner_is_active:
        print('     - Service is not currently active')

# Application auto-start analysis
if app_service_check.get('stdout') and 'No application service found' not in app_service_check.get('stdout', ''):
    print('  ✅ Application: HAS AUTO-START SERVICE')
else:
    print('  ❌ Application: NO AUTO-START SERVICE')
    print('     - Application will need manual restart after server reboot')
    print('     - Deployments will succeed but app won\'t auto-start')

print('\n[RECOMMENDATIONS FOR FULL AUTO-STARTUP]')

if not runner_is_enabled:
    print('\n1. ENABLE RUNNER AUTO-START:')
    print('   - Command: systemctl enable actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')

if 'No application service found' in app_service_check.get('stdout', ''):
    print('\n2. CREATE APPLICATION AUTO-START SERVICE:')
    print('   - Create systemd service for the deployed application')
    print('   - Service should start the latest deployed version')
    print('   - Configure to restart on failures')

print('\n3. RECOMMENDED SERVICE CONFIGURATION:')
print('   - Application service should depend on network being available')
print('   - Should automatically start the current deployment symlink')
print('   - Should restart automatically if the application crashes')

print('\n[TEST RECOMMENDATIONS]')
print('1. Test runner restart: systemctl restart actions.runner...')
print('2. Test system reboot simulation')
print('3. Verify application auto-starts after reboot')
print('4. Confirm CI/CD pipeline works immediately after restart')

print('\n[IMMEDIATE ACTIONS NEEDED]')
if not runner_is_enabled:
    print('  🔧 Enable runner service for auto-start')
if 'No application service found' in app_service_check.get('stdout', ''):
    print('  🔧 Create application systemd service')
if runner_is_enabled and app_is_running:
    print('  ✅ System is well-configured for restart survival')

print('=' * 60)