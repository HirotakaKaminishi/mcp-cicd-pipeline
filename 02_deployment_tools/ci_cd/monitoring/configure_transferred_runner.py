#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Configure GitHub Actions Runner after file transfer
"""

import requests
import json

def execute_command(command, timeout=60):
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

print('GitHub Actions Runner Configuration (After File Transfer)')
print('=' * 60)

# Step 1: Check if file exists and its size
print('\nStep 1: Checking transferred file...')
cmd = 'ls -lh /home/actions-runner/actions-runner/*.tar.gz'
result = execute_command(cmd)
if result.get('stdout'):
    print('[OK] File found:', result['stdout'].strip())
    # Check if file size is reasonable
    if any(size in result['stdout'] for size in ['100M', '101M', '102M']):
        print('[SUCCESS] File size looks correct!')
    else:
        print('[WARNING] File size might be wrong. Expected ~101MB')
else:
    print('[ERROR] File not found:', result.get('stderr', 'Unknown'))
    exit(1)

# Step 2: Extract the tar.gz file
print('\nStep 2: Extracting Runner archive...')
cmd = 'cd /home/actions-runner/actions-runner && tar xzf actions-runner-linux-x64-2.327.1.tar.gz'
result = execute_command(cmd, timeout=90)
if result.get('returncode') == 0:
    print('[SUCCESS] Archive extracted successfully')
else:
    print('[ERROR] Extraction failed:', result.get('stderr', 'Unknown error'))
    if result.get('stderr'):
        print('Error details:', result['stderr'])

# Step 3: Check extracted contents
print('\nStep 3: Verifying extracted files...')
cmd = 'ls -la /home/actions-runner/actions-runner/ | grep -E "\.(sh|json)$|^d" | head -10'
result = execute_command(cmd)
if result.get('stdout'):
    print('[OK] Key files found:')
    for line in result['stdout'].split('\n'):
        if line.strip():
            print('  ', line)

# Step 4: Set proper permissions
print('\nStep 4: Setting permissions...')
cmd = 'chown -R actions-runner:actions-runner /home/actions-runner/actions-runner && chmod +x /home/actions-runner/actions-runner/*.sh'
result = execute_command(cmd)
if result.get('returncode') == 0:
    print('[SUCCESS] Permissions set')
else:
    print('[INFO] Permission setting:', result.get('stderr', 'Unknown'))

# Step 5: Configure runner with token
print('\nStep 5: Configuring Runner with GitHub token...')
print('Using token: BF6BGAESVJWCAOLT6DM4A6LITGOYY')
cmd = '''cd /home/actions-runner/actions-runner && sudo -u actions-runner ./config.sh --url https://github.com/HirotakaKaminishi/mcp-cicd-pipeline --token BF6BGAESVJWCAOLT6DM4A6LITGOYY --name mcp-server-runner --labels self-hosted,linux,x64,mcp-server --unattended --replace'''
result = execute_command(cmd, timeout=120)

if result.get('stdout'):
    print('[CONFIG OUTPUT]')
    for line in result['stdout'].split('\n'):
        if line.strip():
            print('  ', line)

if result.get('stderr'):
    print('[CONFIG MESSAGES]')
    for line in result['stderr'].split('\n'):
        if line.strip() and 'ldd:' not in line:  # Skip library warnings
            print('  ', line)

# Step 6: Check configuration files
print('\nStep 6: Verifying configuration...')
cmd = 'ls -la /home/actions-runner/actions-runner/.runner /home/actions-runner/actions-runner/.credentials 2>/dev/null || echo "Configuration files not found"'
result = execute_command(cmd)
if result.get('stdout') and 'not found' not in result['stdout']:
    print('[SUCCESS] Configuration files created:')
    print(result['stdout'])
else:
    print('[WARNING] Configuration may have failed')
    print(result.get('stdout', 'Unknown'))

# Step 7: Install as service (if svc.sh exists)
print('\nStep 7: Installing Runner service...')
cmd = 'cd /home/actions-runner/actions-runner && test -f svc.sh && sudo ./svc.sh install || echo "Service installation: svc.sh not available or failed"'
result = execute_command(cmd)
if result.get('stdout'):
    print('[SERVICE]', result['stdout'])

# Step 8: Start the runner
print('\nStep 8: Starting Runner...')
cmd = 'cd /home/actions-runner/actions-runner && sudo -u actions-runner nohup ./run.sh > runner.log 2>&1 &'
result = execute_command(cmd)
print('[OK] Runner start command executed')

# Step 9: Wait and check if runner is running
print('\nStep 9: Checking Runner status...')
import time
time.sleep(5)  # Wait for runner to start

cmd = 'ps aux | grep -E "Runner.Listener|run.sh" | grep -v grep'
result = execute_command(cmd)
if result.get('stdout'):
    print('[SUCCESS] Runner processes found:')
    for line in result['stdout'].split('\n'):
        if line.strip():
            print('  ', line)
else:
    print('[INFO] No runner processes found yet. Checking logs...')

# Step 10: Check runner logs
print('\nStep 10: Checking Runner logs...')
cmd = 'tail -15 /home/actions-runner/actions-runner/runner.log 2>/dev/null || tail -15 /home/actions-runner/actions-runner/_diag/*.log 2>/dev/null || echo "No logs found"'
result = execute_command(cmd)
if result.get('stdout'):
    print('[LOGS] Recent entries:')
    for line in result['stdout'].split('\n')[-10:]:
        if line.strip():
            print('  ', line)

# Step 11: Final status check
print('\nStep 11: Final configuration verification...')
cmd = '''cd /home/actions-runner/actions-runner && echo "=== Configuration Check ===" && ls -la .runner .credentials 2>/dev/null && echo "=== Process Check ===" && pgrep -f "Runner" || echo "No Runner processes"'''
result = execute_command(cmd)
if result.get('stdout'):
    print('[FINAL CHECK]')
    print(result['stdout'])

print('\n' + '=' * 60)
print('Configuration Complete!')
print('\nNext Steps:')
print('1. Check GitHub Repository Settings:')
print('   https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('2. Look for "mcp-server-runner" in the list with "Online" status')
print('3. If online, test with a workflow using: runs-on: self-hosted')
print('\nFor service mode (auto-start):')
print('   cd /home/actions-runner/actions-runner')
print('   sudo ./svc.sh install')
print('   sudo ./svc.sh start')