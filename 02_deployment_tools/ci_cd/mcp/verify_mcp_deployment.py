#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verify Actual Deployment on MCP Server
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

print('Verifying MCP Server Deployment Status')
print('=' * 50)
print(f'Verification Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
print('Target: Commit f94f876 - Runner label fix')
print('Expected: Files deployed to /root/mcp_project/')
print('=' * 50)

# Check deployment directory structure
print('\n[1] Checking deployment directory structure...')
deploy_structure = execute_mcp_command('ls -la /root/mcp_project/')
if deploy_structure.get('stdout'):
    print('[STRUCTURE] Project directory contents:')
    for line in deploy_structure['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[ERROR] Cannot access /root/mcp_project/')

# Check releases directory
print('\n[2] Checking releases directory...')
releases_check = execute_mcp_command('ls -lt /root/mcp_project/releases/ | head -5')
if releases_check.get('stdout'):
    print('[RELEASES] Recent releases:')
    for line in releases_check['stdout'].split('\n'):
        if line.strip() and not line.startswith('total'):
            print(f'  {line}')

# Check current deployment symlink
print('\n[3] Checking current deployment...')
current_check = execute_mcp_command('ls -la /root/mcp_project/current')
if current_check.get('stdout'):
    print('[CURRENT] Active deployment:')
    for line in current_check['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check deployment log for recent commits
print('\n[4] Checking deployment log...')
deploy_log = execute_mcp_command('tail -10 /root/mcp_project/deployment.log 2>/dev/null')
if deploy_log.get('stdout'):
    print('[LOG] Recent deployment entries:')
    for line in deploy_log['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Look for specific commit (f94f876)
print('\n[5] Searching for commit f94f876...')
commit_search = execute_mcp_command('grep "f94f876" /root/mcp_project/deployment.log 2>/dev/null')
if commit_search.get('stdout'):
    print('[FOUND] Commit f94f876 deployment:')
    for line in commit_search['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[NOT FOUND] Commit f94f876 not found in deployment log')

# Check for latest deployment files
print('\n[6] Checking latest deployment content...')
latest_release = execute_mcp_command('ls -t /root/mcp_project/releases/ | head -1')
if latest_release.get('stdout'):
    latest_dir = latest_release['stdout'].strip()
    if latest_dir:
        print(f'[LATEST] Most recent release: {latest_dir}')
        
        # Check contents of latest release
        release_contents = execute_mcp_command(f'ls -la /root/mcp_project/releases/{latest_dir}/')
        if release_contents.get('stdout'):
            print('[CONTENTS] Latest release contents:')
            for line in release_contents['stdout'].split('\n'):
                if line.strip():
                    print(f'  {line}')
        
        # Check deployment metadata
        metadata_check = execute_mcp_command(f'cat /root/mcp_project/releases/{latest_dir}/deployment.json 2>/dev/null')
        if metadata_check.get('stdout'):
            print('[METADATA] Deployment metadata:')
            try:
                metadata = json.loads(metadata_check['stdout'])
                for key, value in metadata.items():
                    print(f'  {key}: {value}')
            except:
                print(f'  {metadata_check["stdout"]}')

# Check if application files exist
print('\n[7] Checking application files...')
app_files = execute_mcp_command('find /root/mcp_project/current/ -name "*.js" -o -name "*.json" 2>/dev/null')
if app_files.get('stdout'):
    print('[APP FILES] Application files found:')
    for line in app_files['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')

# Check if Node.js application is running
print('\n[8] Checking if application is running...')
app_process = execute_mcp_command('ps aux | grep node | grep -v grep')
if app_process.get('stdout'):
    print('[PROCESS] Node.js processes:')
    for line in app_process['stdout'].split('\n'):
        if line.strip():
            print(f'  {line}')
else:
    print('[PROCESS] No Node.js processes found')

# Test application endpoint if running
print('\n[9] Testing application endpoint...')
app_test = execute_mcp_command('curl -s http://localhost:3000/ 2>/dev/null')
if app_test.get('stdout'):
    print('[ENDPOINT] Application response:')
    try:
        response = json.loads(app_test['stdout'])
        for key, value in response.items():
            print(f'  {key}: {value}')
    except:
        print(f'  {app_test["stdout"][:200]}')
else:
    print('[ENDPOINT] Application not responding on port 3000')

# Check health endpoint
health_test = execute_mcp_command('curl -s http://localhost:3000/health 2>/dev/null')
if health_test.get('stdout'):
    print('[HEALTH] Health endpoint response:')
    try:
        response = json.loads(health_test['stdout'])
        for key, value in response.items():
            print(f'  {key}: {value}')
    except:
        print(f'  {health_test["stdout"][:200]}')

print('\n' + '=' * 50)
print('DEPLOYMENT VERIFICATION SUMMARY')
print('=' * 50)

# Final verification summary
latest_commit_check = execute_mcp_command('grep -E "(f94f876|queue.*fix)" /root/mcp_project/deployment.log 2>/dev/null | tail -1')
if latest_commit_check.get('stdout'):
    print('[SUCCESS] Latest deployment found:')
    print(f'  {latest_commit_check["stdout"].strip()}')
    deployment_verified = True
else:
    print('[WARNING] Latest commit deployment not found in logs')
    deployment_verified = False

# Check current deployment timestamp
current_timestamp = execute_mcp_command('stat -c %Y /root/mcp_project/current 2>/dev/null')
if current_timestamp.get('stdout'):
    timestamp = int(current_timestamp['stdout'].strip())
    deploy_time = datetime.fromtimestamp(timestamp)
    current_time = datetime.now()
    time_diff = (current_time - deploy_time).total_seconds()
    
    print(f'[TIMESTAMP] Current deployment updated: {deploy_time.strftime("%Y-%m-%d %H:%M:%S")}')
    print(f'[AGE] Deployment age: {int(time_diff//60)} minutes ago')
    
    # Recent deployment (within last 30 minutes) indicates success
    if time_diff < 1800:  # 30 minutes
        recent_deploy = True
    else:
        recent_deploy = False
else:
    recent_deploy = False

print('\n[FINAL RESULT]')
if deployment_verified and recent_deploy:
    print('✅ DEPLOYMENT VERIFIED: CI/CD pipeline successfully deployed to MCP server')
    print('✅ Recent deployment detected')
    print('✅ Files are properly deployed and accessible')
elif deployment_verified:
    print('✅ DEPLOYMENT FOUND: Files deployed but may not be the latest')
    print('⚠️  Check deployment timestamp')
elif recent_deploy:
    print('⚠️  RECENT ACTIVITY: Recent deployment detected but commit not confirmed')
    print('⚠️  Deployment may have succeeded but logging incomplete')
else:
    print('❌ DEPLOYMENT NOT VERIFIED: No recent deployment activity detected')
    print('❌ Check CI/CD pipeline logs for issues')

print('\n[RECOMMENDATIONS]')
if deployment_verified and recent_deploy:
    print('- CI/CD pipeline is working correctly')
    print('- Self-hosted runner successfully deploying to MCP server')
    print('- Consider setting up application auto-start service')
else:
    print('- Review GitHub Actions logs for deployment step details')
    print('- Check MCP server disk space and permissions')
    print('- Verify runner has proper access to deployment directory')

print('=' * 50)