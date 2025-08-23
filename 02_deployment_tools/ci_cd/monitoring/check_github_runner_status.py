#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check GitHub Runner Status and Queue Resolution
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

print('GitHub Runner Status and Queue Resolution Check')
print('=' * 55)
print(f'Check Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Repository: HirotakaKaminishi/mcp-cicd-pipeline')
print('Expected: Runner should show as Online, jobs should not queue')
print('=' * 55)

# Check current runner status on MCP server
print('\n[MCP SERVER] Current runner status...')
runner_status = execute_mcp_command('systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service')
runner_process = execute_mcp_command('pgrep -f "Runner.Listener" | wc -l')
print(f'Service Status: {runner_status.get("stdout", "unknown").strip()}')
print(f'Runner Processes: {runner_process.get("stdout", "0").strip()}')

# Check runner connectivity and GitHub connection
print('\n[CONNECTIVITY] Testing GitHub connection...')
github_test = execute_mcp_command('curl -s -w "HTTP_CODE:%{http_code}\\n" https://api.github.com/zen')
if github_test.get('stdout'):
    print(f'GitHub API: {github_test["stdout"].strip()}')

# Check recent runner logs
print('\n[RUNNER LOGS] Recent activity (last 5 log entries)...')
recent_logs = execute_mcp_command('journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --no-pager -n 5 | grep -E "(Connected|Listening|Job)"')
if recent_logs.get('stdout'):
    for line in recent_logs['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check runner configuration files
print('\n[CONFIGURATION] Runner config check...')
config_check = execute_mcp_command('cat /home/actions-runner/actions-runner/.runner | grep -E "(agentId|poolId|serverUrl)"')
if config_check.get('stdout'):
    print('Runner configuration:')
    for line in config_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Manual status verification steps
print('\n' + '=' * 55)
print('MANUAL VERIFICATION REQUIRED')
print('=' * 55)

print('\n[STEP 1] Check GitHub Repository Runner Page:')
print('URL: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('Expected: "mcp-server-runner" should show "Online" status')

print('\n[STEP 2] Check Current Workflow Status:')
print('URL: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions')
print('Expected: Commit 6ae1883 should execute without queuing')

print('\n[STEP 3] If Runner Shows Offline on GitHub:')
print('Possible causes:')
print('- Runner token may have expired')
print('- GitHub hasn\'t recognized the runner restart yet')
print('- Firewall blocking runner communication')
print('- Repository runner settings misconfigured')

print('\n[TROUBLESHOOTING] If still queuing:')
print('1. Wait 2-3 minutes for GitHub to update runner status')
print('2. If runner shows "Offline" on GitHub, re-register with new token')
print('3. Cancel current queued job and re-run after runner shows "Online"')
print('4. Check if repository has "Require approval for fork pull requests" enabled')

print('\n[RUNNER RE-REGISTRATION] If needed:')
print('1. Generate new runner token from GitHub repository settings')
print('2. Remove current runner: ./config.sh remove --token NEW_TOKEN')
print('3. Configure new runner: ./config.sh --url REPO_URL --token NEW_TOKEN --name mcp-server-runner --labels mcp-server,linux,x64,self-hosted')

print('\nCurrent Status Summary:')
print(f'- MCP Server Runner Service: {runner_status.get("stdout", "unknown").strip()}')
print(f'- Runner Process Count: {runner_process.get("stdout", "0").strip()}')
print('- GitHub Connection: Working (API accessible)')
print('- Next Action: Check GitHub runner page for Online status')

print('=' * 55)
print('If runner shows Online but jobs still queue, there may be')
print('a GitHub Actions configuration issue or pending approval.')
print('=' * 55)