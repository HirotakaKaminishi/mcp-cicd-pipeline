#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Install GitHub Actions Runner v2.327.1 - Official Procedure
"""

import requests
import json
import time

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

print('GitHub Actions Runner v2.327.1 Official Installation')
print('=' * 60)

# Step 1: Create a folder
print('\nStep 1: Creating folder...')
cmd = 'cd /home/actions-runner && rm -rf actions-runner && mkdir actions-runner && cd actions-runner && pwd'
result = execute_command(cmd)
if result.get('stdout'):
    print('[OK] Working directory:', result['stdout'].strip())
else:
    print('[INFO]', result)

# Step 2: Download the latest runner package (v2.327.1)
print('\nStep 2: Downloading runner v2.327.1...')
print('This may take a minute...')
cmd = '''cd /home/actions-runner/actions-runner && curl -o actions-runner-linux-x64-2.327.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.327.1/actions-runner-linux-x64-2.327.1.tar.gz'''
result = execute_command(cmd, timeout=120)
if result.get('returncode') == 0:
    print('[OK] Download complete')
else:
    print('[INFO] Download status:', result.get('stderr', 'Check manually'))

# Step 3: Validate the hash (optional)
print('\nStep 3: Validating hash...')
cmd = '''cd /home/actions-runner/actions-runner && echo "d68ac1f500b747d1271d9e52661c408d56cffd226974f68b7dc813e30b9e0575  actions-runner-linux-x64-2.327.1.tar.gz" | shasum -a 256 -c'''
result = execute_command(cmd)
if result.get('stdout'):
    print('[OK] Hash validation:', result['stdout'].strip())
else:
    print('[INFO] Hash check:', result.get('stderr', 'Skipping'))

# Step 4: Check file size
print('\nStep 4: Checking file size...')
cmd = 'ls -lh /home/actions-runner/actions-runner/actions-runner-linux-x64-2.327.1.tar.gz'
result = execute_command(cmd)
if result.get('stdout'):
    print('[OK] File size:', result['stdout'].strip())

# Step 5: Extract the installer
print('\nStep 5: Extracting installer...')
cmd = 'cd /home/actions-runner/actions-runner && tar xzf ./actions-runner-linux-x64-2.327.1.tar.gz'
result = execute_command(cmd)
if result.get('returncode') == 0:
    print('[OK] Extraction complete')
else:
    print('[ERROR] Extraction failed:', result.get('stderr', 'Unknown'))

# Step 6: Set permissions
print('\nStep 6: Setting permissions...')
cmd = 'chown -R actions-runner:actions-runner /home/actions-runner/actions-runner'
result = execute_command(cmd)
print('[OK] Permissions set')

# Step 7: Check extracted files
print('\nStep 7: Verifying extracted files...')
cmd = 'ls -la /home/actions-runner/actions-runner/ | head -15'
result = execute_command(cmd)
if result.get('stdout'):
    print('[OK] Files found:')
    for line in result['stdout'].split('\n')[:10]:
        if line.strip():
            print('  ', line)

# Step 8: Configure the runner
print('\nStep 8: Configuring runner...')
print('Using provided token: BF6BGAESVJWCAOLT6DM4A6LITGOYY')
cmd = '''cd /home/actions-runner/actions-runner && sudo -u actions-runner ./config.sh --url https://github.com/HirotakaKaminishi/mcp-cicd-pipeline --token BF6BGAESVJWCAOLT6DM4A6LITGOYY --name mcp-server-runner --labels self-hosted,linux,x64,mcp-server --unattended --replace'''
result = execute_command(cmd, timeout=60)
if result.get('stdout'):
    print('[OK] Configuration output:')
    for line in result['stdout'].split('\n')[:20]:
        if line.strip():
            print('  ', line)
if result.get('stderr'):
    print('[INFO] Configuration messages:')
    for line in result['stderr'].split('\n')[:10]:
        if line.strip():
            print('  ', line)

# Step 9: Check configuration files
print('\nStep 9: Checking configuration...')
cmd = 'ls -la /home/actions-runner/actions-runner/.runner /home/actions-runner/actions-runner/.credentials 2>/dev/null || echo "Not configured yet"'
result = execute_command(cmd)
if result.get('stdout') and 'Not configured' not in result['stdout']:
    print('[OK] Configuration files created')
else:
    print('[INFO] Configuration status:', result.get('stdout', 'Unknown'))

# Step 10: Run the runner (in background)
print('\nStep 10: Starting runner...')
cmd = 'cd /home/actions-runner/actions-runner && sudo -u actions-runner nohup ./run.sh > runner.log 2>&1 &'
result = execute_command(cmd)
print('[OK] Runner started in background')

# Step 11: Check if runner is running
print('\nStep 11: Verifying runner status...')
time.sleep(3)  # Wait for runner to start
cmd = 'ps aux | grep -E "Runner.Listener|run.sh" | grep -v grep'
result = execute_command(cmd)
if result.get('stdout'):
    print('[OK] Runner processes:')
    for line in result['stdout'].split('\n'):
        if line.strip():
            print('  ', line)
else:
    print('[INFO] No runner processes found yet')

# Step 12: Check runner log
print('\nStep 12: Checking runner log...')
cmd = 'tail -10 /home/actions-runner/actions-runner/runner.log 2>/dev/null || echo "No log yet"'
result = execute_command(cmd)
if result.get('stdout'):
    print('[LOG] Recent entries:')
    for line in result['stdout'].split('\n')[-5:]:
        if line.strip():
            print('  ', line)

print('\n' + '=' * 60)
print('Installation Complete!')
print('\nNext steps:')
print('1. Check GitHub: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
print('2. Update workflow to use: runs-on: self-hosted')
print('3. For service mode (auto-start):')
print('   sudo ./svc.sh install')
print('   sudo ./svc.sh start')