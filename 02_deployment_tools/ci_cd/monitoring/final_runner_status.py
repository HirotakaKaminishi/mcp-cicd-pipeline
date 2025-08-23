#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Final GitHub Actions Runner Status Check
"""

import requests
import json
from datetime import datetime

def execute_remote_command(command):
    """Execute command on remote server via MCP"""
    url = "http://192.168.111.200:8080"
    
    payload = {
        "method": "execute_command",
        "params": {"command": command}
    }
    
    try:
        response = requests.post(url, json=payload, headers={'Content-Type': 'application/json'}, timeout=30)
        if response.status_code == 200:
            result = response.json()
            if 'result' in result and isinstance(result['result'], dict):
                stdout = result['result'].get('stdout', '')
                stderr = result['result'].get('stderr', '')
                returncode = result['result'].get('returncode', -1)
                
                output = stdout
                if stderr:
                    output += f"\\n[STDERR]: {stderr}"
                
                return {
                    'output': output.strip(),
                    'returncode': returncode,
                    'success': returncode == 0
                }
    except Exception as e:
        return {
            'output': f"実行エラー: {str(e)}",
            'returncode': -1,
            'success': False
        }
    
    return {
        'output': f"コマンド実行失敗: {command}",
        'returncode': -1,
        'success': False
    }

def main():
    print("GitHub Actions Self-hosted Runner 最終ステータスレポート")
    print("=" * 70)
    print(f"生成日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"対象サーバー: 192.168.111.200:8080")
    print("=" * 70)
    
    # 詳細なステータスチェック
    checks = [
        {
            "title": "1. Runner ディレクトリ構造",
            "commands": [
                "ls -la /home/actions-runner/actions-runner/",
                "find /home/actions-runner/actions-runner/ -type f -name '*.sh' | head -10",
                "find /home/actions-runner/actions-runner/ -name '.*' | head -10",
                "du -sh /home/actions-runner/actions-runner/",
            ]
        },
        {
            "title": "2. Runner 設定確認",
            "commands": [
                "test -f /home/actions-runner/actions-runner/.runner && echo '.runner file EXISTS' || echo '.runner file NOT EXISTS'",
                "test -f /home/actions-runner/actions-runner/.credentials && echo '.credentials file EXISTS' || echo '.credentials file NOT EXISTS'",
                "cat /home/actions-runner/actions-runner/.runner 2>/dev/null | head -10 || echo '.runner file not readable'",
                "ls -la /home/actions-runner/actions-runner/.* 2>/dev/null | grep -v '^d' || echo 'No hidden files found'",
            ]
        },
        {
            "title": "3. Runner サービス状態",
            "commands": [
                "systemctl status actions-runner.service 2>/dev/null || echo 'actions-runner.service not found'",
                "systemctl is-enabled actions-runner.service 2>/dev/null || echo 'Service not enabled'",
                "systemctl is-active actions-runner.service 2>/dev/null || echo 'Service not active'",
                "find /etc/systemd/system -name '*actions*' -o -name '*runner*' 2>/dev/null || echo 'No systemd service files found'",
            ]
        },
        {
            "title": "4. Runner プロセス状態",
            "commands": [
                "ps aux | grep -i runner | grep -v grep",
                "pgrep -fl Runner",
                "pgrep -fl actions-runner",
                "lsof -i :8080 2>/dev/null || echo 'No processes on port 8080'",
            ]
        },
        {
            "title": "5. Runner ログ確認",
            "commands": [
                "find /home/actions-runner -name '*.log' 2>/dev/null | head -5",
                "journalctl -u actions-runner.service --no-pager -n 10 2>/dev/null || echo 'No systemd logs'",
                "tail -20 /var/log/messages 2>/dev/null | grep -i runner || echo 'No runner entries in system log'",
                "ls -la /tmp/*runner* 2>/dev/null || echo 'No runner temp files'",
            ]
        },
        {
            "title": "6. ユーザーとアクセス権限",
            "commands": [
                "id actions-runner",
                "groups actions-runner",
                "ls -la /home/actions-runner/",
                "sudo -u actions-runner whoami 2>/dev/null || echo 'Cannot switch to actions-runner user'",
            ]
        },
        {
            "title": "7. GitHub接続性とネットワーク",
            "commands": [
                "curl -s -I https://api.github.com | head -1",
                "ping -c 1 github.com | head -2",
                "curl -s https://api.github.com/zen",
                "curl -s -I https://github.com | head -1",
            ]
        },
        {
            "title": "8. システム依存関係",
            "commands": [
                "which curl wget git node npm || echo 'Some tools missing'",
                "node --version 2>/dev/null || echo 'Node.js not found'",
                "git --version",
                "python3 --version",
            ]
        },
        {
            "title": "9. Runner インストール完全性チェック",
            "commands": [
                "ls -la /home/actions-runner/actions-runner/bin/ 2>/dev/null || echo 'No bin directory'",
                "file /home/actions-runner/actions-runner/run.sh 2>/dev/null || echo 'run.sh not found'",
                "head -5 /home/actions-runner/actions-runner/run.sh 2>/dev/null || echo 'Cannot read run.sh'",
                "test -x /home/actions-runner/actions-runner/config.sh && echo 'config.sh is executable' || echo 'config.sh not executable'",
            ]
        }
    ]
    
    for section in checks:
        print(f"\\n{section['title']}")
        print("-" * 60)
        
        for cmd in section['commands']:
            print(f"\\n[CMD] コマンド: {cmd}")
            result = execute_remote_command(cmd)
            
            if result['success']:
                if result['output']:
                    print("[OK] 結果:")
                    for line in result['output'].split('\\n')[:10]:  # Limit to 10 lines
                        if line.strip():
                            print(f"   {line}")
                else:
                    print("[OK] 結果: (出力なし)")
            else:
                print(f"[ERROR] エラー: {result['output']}")
    
    # サマリー判定
    print(f"\\n{'='*70}")
    print("[SUMMARY] GitHub Actions Self-hosted Runner 状態サマリー")
    print(f"{'='*70}")
    
    # Critical checks
    runner_exists = execute_remote_command("test -d /home/actions-runner/actions-runner && echo 'YES' || echo 'NO'")
    config_exists = execute_remote_command("test -f /home/actions-runner/actions-runner/.runner && echo 'YES' || echo 'NO'")
    service_active = execute_remote_command("systemctl is-active actions-runner.service 2>/dev/null || echo 'inactive'")
    process_running = execute_remote_command("pgrep -f 'Runner.Listener' >/dev/null && echo 'YES' || echo 'NO'")
    github_conn = execute_remote_command("curl -s -I https://api.github.com | head -1 | grep -q '200' && echo 'OK' || echo 'FAIL'")
    
    print(f"[CHECK] Runnerディレクトリ存在: {runner_exists['output']}")
    print(f"[CHECK] Runner設定ファイル: {config_exists['output']}")
    print(f"[CHECK] サービス状態: {service_active['output']}")
    print(f"[CHECK] Runnerプロセス: {process_running['output']}")
    print(f"[CHECK] GitHub接続性: {github_conn['output']}")
    
    # 総合判定
    print(f"\\n{'='*70}")
    if (runner_exists['output'].strip() == 'YES' and 
        config_exists['output'].strip() == 'YES'):
        print("[STATUS] RUNNER インストール済み、設定済み")
        if service_active['output'].strip() == 'active':
            print("[SERVICE] 稼働中")
        else:
            print("[SERVICE] 停止中または未設定")
    else:
        print("[STATUS] RUNNER 未設定または不完全")
    
    print(f"{'='*70}")
    print("[COMPLETE] レポート生成完了")

if __name__ == "__main__":
    main()