#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GitHub Actions Self-hosted Runner Detailed Status Checker
"""

import requests
import json
import sys
from datetime import datetime

def execute_remote_command(command):
    """Execute command on remote server"""
    url = "http://192.168.111.200:8080"
    
    # Try different MCP method formats
    methods_to_try = [
        ("execute_command", {"command": command}),
        ("tools/execute_command", {"command": command}),
        ("call", {"tool": "execute_command", "arguments": {"command": command}}),
        ("execute", {"cmd": command})
    ]
    
    for method, params in methods_to_try:
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        }
        
        try:
            response = requests.post(url, json=payload, headers={'Content-Type': 'application/json'}, timeout=30)
            if response.status_code == 200:
                result = response.json()
                if 'result' in result and 'error' not in result.get('result', {}):
                    return result['result']
                elif 'result' in result and isinstance(result['result'], dict) and result['result'].get('output'):
                    return result['result']['output']
        except Exception as e:
            continue
    
    return f"Command execution failed: {command}"

def generate_runner_report():
    """Generate comprehensive GitHub Actions Runner report in Japanese"""
    
    print("GitHub Actions Self-hosted Runner 詳細ステータスレポート")
    print("=" * 70)
    print(f"生成日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"対象サーバー: 192.168.111.200:8080")
    print("=" * 70)
    
    checks = [
        {
            "title": "1. Runner ディレクトリの確認",
            "commands": [
                "ls -la /home/actions-runner/ 2>/dev/null || echo 'Not found in /home/actions-runner'",
                "ls -la /opt/actions-runner/ 2>/dev/null || echo 'Not found in /opt/actions-runner'",
                "ls -la /usr/local/actions-runner/ 2>/dev/null || echo 'Not found in /usr/local/actions-runner'",
                "find /home -type d -name '*runner*' 2>/dev/null || echo 'No runner directories in /home'",
                "find /opt -type d -name '*runner*' 2>/dev/null || echo 'No runner directories in /opt'"
            ]
        },
        {
            "title": "2. Runner 設定ファイルの確認",
            "commands": [
                "find / -name '.runner' -type f 2>/dev/null | head -5 || echo '.runner file not found'",
                "find / -name '.credentials' -type f 2>/dev/null | head -5 || echo '.credentials file not found'",
                "find / -name 'runsvc.sh' -type f 2>/dev/null | head -5 || echo 'runsvc.sh not found'",
                "find / -name 'config.sh' -path '*/actions-runner/*' 2>/dev/null | head -5 || echo 'config.sh not found'"
            ]
        },
        {
            "title": "3. Runner サービスの確認",
            "commands": [
                "systemctl status actions-runner 2>/dev/null || echo 'actions-runner service not found'",
                "systemctl status github-runner 2>/dev/null || echo 'github-runner service not found'",
                "systemctl list-unit-files | grep -i runner || echo 'No runner services in systemctl'",
                "service --status-all 2>/dev/null | grep -i runner || echo 'No runner services found'"
            ]
        },
        {
            "title": "4. Runner プロセスの確認",
            "commands": [
                "ps aux | grep -i 'runner' | grep -v grep || echo 'No runner processes found'",
                "ps aux | grep -i 'github' | grep -v grep || echo 'No github processes found'",
                "pgrep -fl runner || echo 'No runner processes via pgrep'"
            ]
        },
        {
            "title": "5. Runner ログの確認",
            "commands": [
                "find /var/log -name '*runner*' 2>/dev/null | head -5 || echo 'No runner logs in /var/log'",
                "find /home -name '*runner*.log' 2>/dev/null | head -5 || echo 'No runner logs in /home'",
                "journalctl -u actions-runner --no-pager -n 5 2>/dev/null || echo 'No systemd logs for actions-runner'",
                "ls -la /var/log/ | grep -i runner || echo 'No runner-related files in /var/log'"
            ]
        },
        {
            "title": "6. actions-runner ユーザーの確認",
            "commands": [
                "id actions-runner 2>/dev/null || echo 'actions-runner user not found'",
                "getent passwd | grep -i runner || echo 'No runner users in passwd'",
                "groups actions-runner 2>/dev/null || echo 'Cannot get groups for actions-runner'",
                "sudo -u actions-runner whoami 2>/dev/null || echo 'Cannot switch to actions-runner user'"
            ]
        },
        {
            "title": "7. システム情報とリソース状況",
            "commands": [
                "uname -a",
                "cat /etc/os-release | head -5",
                "free -h",
                "df -h /",
                "whoami",
                "uptime"
            ]
        },
        {
            "title": "8. GitHub接続性とネットワーク確認",
            "commands": [
                "curl -s -I https://api.github.com | head -1 2>/dev/null || echo 'Cannot connect to GitHub API'",
                "ping -c 2 github.com 2>/dev/null || echo 'Cannot ping github.com'",
                "curl -s https://api.github.com/zen 2>/dev/null || echo 'Cannot fetch GitHub zen'",
                "netstat -tuln | grep :443 || echo 'No HTTPS connections'"
            ]
        },
        {
            "title": "9. Docker/Containerランタイムの確認",
            "commands": [
                "docker --version 2>/dev/null || echo 'Docker not installed'",
                "docker ps 2>/dev/null || echo 'Cannot list Docker containers'",
                "podman --version 2>/dev/null || echo 'Podman not installed'",
                "which containerd 2>/dev/null || echo 'containerd not found'"
            ]
        },
        {
            "title": "10. インストール状況の全般確認",
            "commands": [
                "which curl wget git || echo 'Some basic tools missing'",
                "ls -la /usr/bin/ | grep -E '(node|npm|python|java)' | head -5 || echo 'Development tools status'",
                "find /tmp -name '*runner*' 2>/dev/null | head -5 || echo 'No runner files in /tmp'",
                "crontab -l 2>/dev/null | grep -i runner || echo 'No runner cron jobs'"
            ]
        }
    ]
    
    for check in checks:
        print(f"\n{check['title']}")
        print("-" * 60)
        
        for i, command in enumerate(check['commands'], 1):
            print(f"  {i}. コマンド: {command}")
            result = execute_remote_command(command)
            if isinstance(result, dict):
                if 'output' in result:
                    output = result['output'].strip()
                elif 'stdout' in result:
                    output = result['stdout'].strip()
                else:
                    output = str(result)
            else:
                output = str(result).strip()
            
            if output:
                for line in output.split('\n')[:10]:  # Limit to first 10 lines
                    print(f"     {line}")
            else:
                print("     (出力なし)")
            print()

def main():
    try:
        generate_runner_report()
        
        print("\n" + "=" * 70)
        print("レポート生成完了")
        print("=" * 70)
        print("\n【重要な確認ポイント】")
        print("1. Runner ディレクトリが存在するか")
        print("2. .runner, .credentials ファイルが存在するか")
        print("3. Runnerサービスが稼働中か")
        print("4. Runner プロセスが動作中か")
        print("5. actions-runner ユーザーが存在するか")
        print("6. GitHub への接続性があるか")
        print("7. 必要な依存関係がインストールされているか")
        
    except Exception as e:
        print(f"❌ エラーが発生しました: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()