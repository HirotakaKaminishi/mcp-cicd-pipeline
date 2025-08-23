#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GitHub Actions Self-hosted Runner Status Checker
"""

import requests
import json
import sys

class MCPClient:
    def __init__(self, server_url):
        self.server_url = server_url
        self.headers = {'Content-Type': 'application/json'}
    
    def execute_command(self, command):
        """Execute command on remote server via MCP"""
        payload = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "execute_command",
                "arguments": {
                    "command": command
                }
            },
            "id": 1
        }
        
        try:
            response = requests.post(self.server_url, json=payload, headers=self.headers, timeout=30)
            return response.json()
        except Exception as e:
            return {"error": str(e)}

def check_runner_status():
    """Check GitHub Actions Self-hosted Runner status"""
    client = MCPClient("http://192.168.111.200:8080")
    
    results = {}
    
    # 1. Check if runner directory exists
    print("1. Runner ディレクトリの確認中...")
    cmd = "ls -la /home/actions-runner/ 2>/dev/null || ls -la /opt/actions-runner/ 2>/dev/null || ls -la /usr/local/actions-runner/ 2>/dev/null || echo 'Runner directory not found in standard locations'"
    results['runner_directory'] = client.execute_command(cmd)
    
    # 2. Check runner configuration files
    print("2. Runner 設定ファイルの確認中...")
    cmd = "find /home -name '.runner' -o -name '.credentials' 2>/dev/null || find /opt -name '.runner' -o -name '.credentials' 2>/dev/null || echo 'Runner config files not found'"
    results['runner_config'] = client.execute_command(cmd)
    
    # 3. Check runner service status
    print("3. Runner サービスの確認中...")
    cmd = "systemctl status actions-runner 2>/dev/null || systemctl status github-runner 2>/dev/null || service actions-runner status 2>/dev/null || echo 'No runner service found'"
    results['runner_service'] = client.execute_command(cmd)
    
    # 4. Check runner processes
    print("4. Runner プロセスの確認中...")
    cmd = "ps aux | grep -i runner | grep -v grep || echo 'No runner processes found'"
    results['runner_processes'] = client.execute_command(cmd)
    
    # 5. Check runner logs
    print("5. Runner ログの確認中...")
    cmd = "find /var/log -name '*runner*' 2>/dev/null || find /home -name '*runner*.log' 2>/dev/null || journalctl -u actions-runner --no-pager -n 10 2>/dev/null || echo 'No runner logs found'"
    results['runner_logs'] = client.execute_command(cmd)
    
    # 6. Check actions-runner user
    print("6. actions-runner ユーザーの確認中...")
    cmd = "id actions-runner 2>/dev/null || getent passwd | grep runner || echo 'No actions-runner user found'"
    results['runner_user'] = client.execute_command(cmd)
    
    # 7. Check system info
    print("7. システム情報の取得中...")
    cmd = "uname -a && cat /etc/os-release | head -5 && free -h && df -h / && whoami"
    results['system_info'] = client.execute_command(cmd)
    
    # 8. Check network connectivity to GitHub
    print("8. GitHub接続性の確認中...")
    cmd = "curl -s -I https://api.github.com | head -1 || echo 'GitHub connectivity check failed'"
    results['github_connectivity'] = client.execute_command(cmd)
    
    return results

def print_japanese_report(results):
    """Print detailed status report in Japanese"""
    print("\n" + "="*80)
    print("GitHub Actions Self-hosted Runner 詳細ステータスレポート")
    print("="*80)
    
    for key, result in results.items():
        section_titles = {
            'runner_directory': '1. Runner ディレクトリの状態',
            'runner_config': '2. Runner 設定ファイルの状態',
            'runner_service': '3. Runner サービスの状態',
            'runner_processes': '4. Runner プロセスの状態',
            'runner_logs': '5. Runner ログの状態',
            'runner_user': '6. actions-runner ユーザーの状態',
            'system_info': '7. システム情報',
            'github_connectivity': '8. GitHub接続性'
        }
        
        print(f"\n{section_titles.get(key, key)}:")
        print("-" * 60)
        
        if 'error' in result:
            print(f"❌ エラー: {result['error']}")
        elif 'result' in result:
            if result['result'].get('output'):
                print(result['result']['output'])
            else:
                print("出力なし")
        else:
            print(f"応答: {json.dumps(result, indent=2, ensure_ascii=False)}")

if __name__ == "__main__":
    print("GitHub Actions Self-hosted Runner ステータス確認を開始します...")
    print(f"対象サーバー: 192.168.111.200:8080")
    
    try:
        results = check_runner_status()
        print_japanese_report(results)
    except Exception as e:
        print(f"❌ エラーが発生しました: {str(e)}")
        sys.exit(1)