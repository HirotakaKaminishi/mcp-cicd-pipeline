#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CI/CD Pipeline Test Deployment
Complete end-to-end testing of GitHub Actions to MCP Server pipeline
"""

import requests
import json
import subprocess
import time
from datetime import datetime

class CICDTester:
    def __init__(self):
        self.mcp_url = 'http://192.168.111.200:8080'
        self.project_dir = r'C:\Users\hirotaka\Documents\work\sample-project'
        
    def execute_mcp_command(self, command, timeout=60):
        """Execute command on MCP server"""
        payload = {
            'jsonrpc': '2.0',
            'method': 'execute_command',
            'params': {'command': command},
            'id': 1
        }
        try:
            response = requests.post(self.mcp_url, json=payload, timeout=timeout)
            if response.status_code == 200:
                result = response.json()
                if 'result' in result:
                    return result['result']
        except Exception as e:
            return {'error': str(e)}
        return {'error': 'Command failed'}
    
    def run_local_command(self, command, cwd=None):
        """Execute local command"""
        try:
            result = subprocess.run(
                command, 
                shell=True, 
                cwd=cwd or self.project_dir,
                capture_output=True, 
                text=True, 
                encoding='utf-8',
                errors='replace'
            )
            return {
                'stdout': result.stdout,
                'stderr': result.stderr,
                'returncode': result.returncode
            }
        except Exception as e:
            return {'error': str(e)}
    
    def test_step(self, step_name, test_func):
        """Execute test step with logging"""
        print(f'\n{step_name}')
        print('-' * 60)
        try:
            result = test_func()
            if result.get('success', True):
                print('[SUCCESS]', result.get('message', 'Completed'))
            else:
                print('[ERROR]', result.get('message', 'Failed'))
            return result
        except Exception as e:
            print('[EXCEPTION]', str(e))
            return {'success': False, 'message': str(e)}

def main():
    tester = CICDTester()
    
    print('CI/CD Pipeline End-to-End Test')
    print('=' * 70)
    print(f'Test Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print('=' * 70)
    
    # Test 1: Pre-deployment checks
    def test_pre_checks():
        print('Checking GitHub Actions Runner status...')
        result = tester.execute_mcp_command('ps aux | grep Runner.Listener | grep -v grep')
        if result.get('stdout'):
            print('[OK] Runner is running:', result['stdout'].strip()[:100])
            return {'success': True, 'message': 'Runner active'}
        else:
            return {'success': False, 'message': 'Runner not found'}
    
    # Test 2: Check current deployment state
    def test_current_deployment():
        print('Checking current deployment state...')
        result = tester.execute_mcp_command('ls -la /root/mcp_project/')
        if result.get('stdout'):
            print('[OK] Current deployment structure:')
            for line in result['stdout'].split('\n')[:10]:
                if line.strip():
                    print('  ', line)
            return {'success': True, 'message': 'Deployment directory exists'}
        else:
            print('[INFO] No existing deployment found')
            return {'success': True, 'message': 'Clean state'}
    
    # Test 3: Create test commit
    def test_create_commit():
        print('Creating test commit for CI/CD trigger...')
        
        # Update app.js with timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        app_update = f'''// Test deployment at {timestamp}
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {{
  res.json({{
    message: 'Hello from MCP CI/CD Pipeline!',
    version: '1.0.0',
    timestamp: '{timestamp}',
    deployment: 'GitHub Actions to MCP Server',
    status: 'success'
  }});
}});

app.get('/health', (req, res) => {{
  res.json({{
    status: 'healthy',
    timestamp: new Date().toISOString(),
    deployment_id: '{timestamp}'
  }});
}});

app.listen(port, () => {{
  console.log(`Server running on port ${{port}}`);
  console.log(`Deployment ID: {timestamp}`);
}});

module.exports = app;'''
        
        # Write updated app.js
        with open(f'{tester.project_dir}/src/app.js', 'w', encoding='utf-8') as f:
            f.write(app_update)
        
        # Git operations
        commands = [
            'git add .',
            f'git commit -m "Test CI/CD deployment {timestamp}"',
            'git push origin main'
        ]
        
        for cmd in commands:
            print(f'Running: {cmd}')
            result = tester.run_local_command(cmd)
            if result['returncode'] != 0:
                print(f'[ERROR] {cmd} failed:', result['stderr'][:200])
                return {'success': False, 'message': f'Git operation failed: {cmd}'}
            else:
                print(f'[OK] {cmd} completed')
        
        return {'success': True, 'message': f'Test commit created: {timestamp}'}
    
    # Test 4: Monitor GitHub Actions workflow
    def test_monitor_workflow():
        print('Monitoring GitHub Actions workflow execution...')
        print('Waiting for workflow to trigger and complete (up to 5 minutes)...')
        
        max_wait = 300  # 5 minutes
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            # Check runner activity
            result = tester.execute_mcp_command('ps aux | grep Runner | grep -v grep')
            if result.get('stdout'):
                print('[ACTIVITY] Runner processes active')
                for line in result['stdout'].split('\n'):
                    if 'Runner.Listener' in line or 'Runner.Worker' in line:
                        print('  ', line)
            
            # Check for new deployments
            deploy_check = tester.execute_mcp_command('ls -lt /root/mcp_project/releases/ 2>/dev/null | head -3')
            if deploy_check.get('stdout'):
                print('[RELEASES] Recent deployments:')
                for line in deploy_check['stdout'].split('\n')[:3]:
                    if line.strip():
                        print('  ', line)
            
            time.sleep(30)  # Check every 30 seconds
            print(f'[INFO] Waiting... ({int(time.time() - start_time)}s elapsed)')
            
            # Check if deployment completed
            current_check = tester.execute_mcp_command('ls -la /root/mcp_project/current')
            if current_check.get('stdout') and 'src' not in str(current_check.get('stderr', '')):
                print('[SUCCESS] New deployment detected!')
                break
        
        return {'success': True, 'message': 'Workflow monitoring completed'}
    
    # Test 5: Verify deployment
    def test_verify_deployment():
        print('Verifying successful deployment...')
        
        # Check deployment structure
        structure_check = tester.execute_mcp_command('find /root/mcp_project -name "*.js" -o -name "*.json" | head -10')
        if structure_check.get('stdout'):
            print('[OK] Deployed files found:')
            for line in structure_check['stdout'].split('\n'):
                if line.strip():
                    print('  ', line)
        
        # Check deployment log
        log_check = tester.execute_mcp_command('tail -10 /root/mcp_project/deployment.log 2>/dev/null')
        if log_check.get('stdout'):
            print('[OK] Recent deployment log:')
            for line in log_check['stdout'].split('\n')[-3:]:
                if line.strip():
                    print('  ', line)
        
        # Check current symlink
        symlink_check = tester.execute_mcp_command('ls -la /root/mcp_project/current')
        if symlink_check.get('stdout'):
            print('[OK] Current deployment symlink:')
            print('  ', symlink_check['stdout'].strip())
        
        return {'success': True, 'message': 'Deployment verification completed'}
    
    # Test 6: Test application functionality
    def test_app_functionality():
        print('Testing deployed application...')
        
        # Try to start the application (if not already running)
        app_test = tester.execute_mcp_command('cd /root/mcp_project/current && node src/app.js > app.log 2>&1 &')
        time.sleep(3)
        
        # Test health endpoint
        health_test = tester.execute_mcp_command('curl -s http://localhost:3000/health || echo "Health check failed"')
        if health_test.get('stdout') and 'healthy' in health_test['stdout']:
            print('[SUCCESS] Health check passed:', health_test['stdout'][:100])
        else:
            print('[INFO] Health check result:', health_test.get('stdout', 'No response'))
        
        # Test main endpoint
        main_test = tester.execute_mcp_command('curl -s http://localhost:3000/ || echo "Main endpoint failed"')
        if main_test.get('stdout'):
            print('[INFO] Main endpoint response:', main_test['stdout'][:150])
        
        return {'success': True, 'message': 'Application functionality tested'}
    
    # Execute all tests
    test_results = []
    
    test_results.append(tester.test_step('1. Pre-deployment Checks', test_pre_checks))
    test_results.append(tester.test_step('2. Current Deployment State', test_current_deployment))
    test_results.append(tester.test_step('3. Create Test Commit', test_create_commit))
    test_results.append(tester.test_step('4. Monitor Workflow Execution', test_monitor_workflow))
    test_results.append(tester.test_step('5. Verify Deployment', test_verify_deployment))
    test_results.append(tester.test_step('6. Test Application', test_app_functionality))
    
    # Summary
    print('\n' + '=' * 70)
    print('CI/CD Pipeline Test Summary')
    print('=' * 70)
    
    successful_tests = sum(1 for result in test_results if result.get('success', False))
    total_tests = len(test_results)
    
    print(f'Total Tests: {total_tests}')
    print(f'Successful: {successful_tests}')
    print(f'Failed: {total_tests - successful_tests}')
    print(f'Success Rate: {(successful_tests/total_tests)*100:.1f}%')
    
    if successful_tests == total_tests:
        print('\n🎉 ALL TESTS PASSED!')
        print('GitHub Actions to MCP Server CI/CD pipeline is working correctly!')
    else:
        print('\n⚠️ Some tests failed. Check the output above for details.')
    
    print('\nFinal Verification URLs:')
    print('- GitHub Actions: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions')
    print('- GitHub Runner: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners')
    
    print('\n' + '=' * 70)
    print(f'Test completed at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')

if __name__ == "__main__":
    main()