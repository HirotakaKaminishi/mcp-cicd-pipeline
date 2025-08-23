#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GitHub Actions Runner Directory Detailed Check
"""

import requests
import json

def execute_remote_command(command):
    """Execute command on remote server"""
    url = "http://192.168.111.200:8080"
    
    payload = {
        "jsonrpc": "2.0",
        "method": "execute_command",
        "params": {"command": command},
        "id": 1
    }
    
    try:
        response = requests.post(url, json=payload, headers={'Content-Type': 'application/json'}, timeout=30)
        if response.status_code == 200:
            result = response.json()
            if 'result' in result and isinstance(result['result'], dict) and 'output' in result['result']:
                return result['result']['output']
    except Exception:
        pass
    
    return f"Failed to execute: {command}"

def main():
    print("GitHub Actions Runner ディレクトリ詳細確認")
    print("=" * 60)
    
    commands = [
        "ls -la /home/actions-runner/actions-runner/",
        "cat /home/actions-runner/actions-runner/config.sh 2>/dev/null | head -20 || echo 'config.sh not readable'",
        "ls -la /home/actions-runner/actions-runner/ | grep -E '\\.(runner|credentials)' || echo 'No config files found'",
        "find /home/actions-runner/actions-runner/ -name '*.sh' -exec ls -la {} \\; || echo 'No shell scripts found'",
        "find /home/actions-runner/actions-runner/ -name 'run.*' -exec ls -la {} \\; || echo 'No run scripts found'",
        "cat /home/actions-runner/actions-runner/.runner 2>/dev/null || echo '.runner file not found or not readable'",
        "ls -la /home/actions-runner/actions-runner/_work/ 2>/dev/null || echo '_work directory not found'",
        "systemctl list-unit-files --type=service | grep -i actions || echo 'No actions services found'",
        "ps aux | grep actions-runner || echo 'No actions-runner processes'",
        "sudo -u actions-runner ls -la /home/actions-runner/actions-runner/ 2>/dev/null || echo 'Cannot list as actions-runner user'"
    ]
    
    for i, cmd in enumerate(commands, 1):
        print(f"\n{i}. {cmd}")
        print("-" * 60)
        result = execute_remote_command(cmd)
        for line in result.split('\n')[:15]:  # Limit output
            if line.strip():
                print(f"  {line}")
    
    print("\n" + "=" * 60)
    print("SUMMARY:")
    print("=" * 60)
    
    # Check runner installation status
    status_check = execute_remote_command("test -f /home/actions-runner/actions-runner/.runner && echo 'CONFIGURED' || echo 'NOT_CONFIGURED'")
    service_check = execute_remote_command("systemctl is-enabled actions-runner 2>/dev/null || echo 'NOT_INSTALLED'")
    process_check = execute_remote_command("pgrep -f 'Runner.Listener' && echo 'RUNNING' || echo 'NOT_RUNNING'")
    
    print(f"Runner Configuration: {status_check.strip()}")
    print(f"Service Installation: {service_check.strip()}")
    print(f"Process Status: {process_check.strip()}")

if __name__ == "__main__":
    main()