#!/bin/bash
# MCP Server Extended インストールスクリプト
# このスクリプトをMCPサーバで実行してください

set -e

echo "========================================="
echo "MCP Server Extended セットアップ"
echo "========================================="

# 1. ディレクトリ作成
echo "[1/5] ディレクトリ作成..."
mkdir -p ~/mcp-server-extended/{config,scripts,logs}
cd ~/mcp-server-extended

# 2. Python依存関係インストール
echo "[2/5] Python依存関係インストール..."
pip3 install jsonrpcserver jsonrpcclient aiohttp

# 3. 設定ファイル作成
echo "[3/5] 設定ファイル作成..."
cat > config/mcp_config.json << 'EOF'
{
  "name": "remote-server-extended",
  "version": "1.0.0",
  "description": "Extended MCP server with file and command execution capabilities",
  "tools": [
    {
      "name": "execute_command",
      "description": "Execute shell commands on the remote server",
      "parameters": {
        "command": {
          "type": "string",
          "description": "Shell command to execute"
        },
        "working_dir": {
          "type": "string",
          "description": "Working directory for command execution",
          "optional": true
        }
      }
    },
    {
      "name": "write_file",
      "description": "Write content to a file on the remote server",
      "parameters": {
        "path": {
          "type": "string",
          "description": "File path to write"
        },
        "content": {
          "type": "string",
          "description": "Content to write to the file"
        },
        "mode": {
          "type": "string",
          "description": "File mode (e.g., '755', '644')",
          "optional": true
        }
      }
    },
    {
      "name": "read_file",
      "description": "Read content from a file on the remote server",
      "parameters": {
        "path": {
          "type": "string",
          "description": "File path to read"
        }
      }
    },
    {
      "name": "list_directory",
      "description": "List contents of a directory",
      "parameters": {
        "path": {
          "type": "string",
          "description": "Directory path to list"
        }
      }
    },
    {
      "name": "install_package",
      "description": "Install packages using package manager",
      "parameters": {
        "package": {
          "type": "string",
          "description": "Package name to install"
        },
        "manager": {
          "type": "string",
          "description": "Package manager (yum, pip, npm)",
          "optional": true
        }
      }
    },
    {
      "name": "manage_service",
      "description": "Manage system services",
      "parameters": {
        "service": {
          "type": "string",
          "description": "Service name"
        },
        "action": {
          "type": "string",
          "description": "Action (start, stop, restart, status)"
        }
      }
    },
    {
      "name": "get_system_info",
      "description": "Get detailed system information",
      "parameters": {}
    }
  ],
  "security": {
    "allowed_paths": [
      "/home",
      "/root/mcp_project",
      "/tmp",
      "/var/log"
    ],
    "denied_paths": [
      "/etc/passwd",
      "/etc/shadow",
      "/root/.ssh"
    ],
    "allowed_commands": [
      "ls",
      "cat",
      "echo",
      "pwd",
      "cd",
      "mkdir",
      "touch",
      "python",
      "python3",
      "pip",
      "pip3",
      "git",
      "npm",
      "node",
      "systemctl",
      "service",
      "yum",
      "dnf",
      "apt-get"
    ],
    "max_file_size": "10MB",
    "timeout": 30
  }
}
EOF

# 4. サーバスクリプト作成
echo "[4/5] サーバスクリプト作成..."
cat > scripts/mcp_server.py << 'EOF'
#!/usr/bin/env python3
"""
MCP Server Extended Implementation
Provides file operations and command execution capabilities
"""

import os
import sys
import json
import subprocess
import shutil
from pathlib import Path
from typing import Dict, Any, Optional

class MCPServerExtended:
    def __init__(self, config_path: str = None):
        self.config = self.load_config(config_path)
        self.security = self.config.get("security", {})
        
    def load_config(self, config_path: str) -> Dict:
        """設定ファイルを読み込み"""
        if config_path and os.path.exists(config_path):
            with open(config_path, 'r') as f:
                return json.load(f)
        return {}
    
    def is_path_allowed(self, path: str) -> bool:
        """パスが許可されているか確認"""
        path = os.path.abspath(path)
        
        # 拒否パスチェック
        for denied in self.security.get("denied_paths", []):
            if path.startswith(denied):
                return False
        
        # 許可パスチェック
        for allowed in self.security.get("allowed_paths", []):
            if path.startswith(allowed):
                return True
        
        return False
    
    def is_command_allowed(self, command: str) -> bool:
        """コマンドが許可されているか確認"""
        cmd_parts = command.split()
        if not cmd_parts:
            return False
        
        base_cmd = cmd_parts[0]
        allowed_commands = self.security.get("allowed_commands", [])
        
        return base_cmd in allowed_commands
    
    def execute_command(self, command: str, working_dir: Optional[str] = None) -> Dict[str, Any]:
        """コマンドを実行"""
        try:
            if not self.is_command_allowed(command):
                return {
                    "success": False,
                    "error": f"Command not allowed: {command}"
                }
            
            if working_dir and not self.is_path_allowed(working_dir):
                return {
                    "success": False,
                    "error": f"Working directory not allowed: {working_dir}"
                }
            
            result = subprocess.run(
                command,
                shell=True,
                cwd=working_dir,
                capture_output=True,
                text=True,
                timeout=self.security.get("timeout", 30)
            )
            
            return {
                "success": True,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
            
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "error": "Command execution timeout"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def write_file(self, path: str, content: str, mode: Optional[str] = None) -> Dict[str, Any]:
        """ファイルに書き込み"""
        try:
            if not self.is_path_allowed(path):
                return {
                    "success": False,
                    "error": f"Path not allowed: {path}"
                }
            
            # ディレクトリが存在しない場合は作成
            os.makedirs(os.path.dirname(path), exist_ok=True)
            
            with open(path, 'w') as f:
                f.write(content)
            
            if mode:
                os.chmod(path, int(mode, 8))
            
            return {
                "success": True,
                "path": path,
                "size": len(content)
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def read_file(self, path: str) -> Dict[str, Any]:
        """ファイルを読み込み"""
        try:
            if not self.is_path_allowed(path):
                return {
                    "success": False,
                    "error": f"Path not allowed: {path}"
                }
            
            if not os.path.exists(path):
                return {
                    "success": False,
                    "error": f"File not found: {path}"
                }
            
            with open(path, 'r') as f:
                content = f.read()
            
            return {
                "success": True,
                "content": content,
                "size": len(content)
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def list_directory(self, path: str) -> Dict[str, Any]:
        """ディレクトリ内容を一覧表示"""
        try:
            if not self.is_path_allowed(path):
                return {
                    "success": False,
                    "error": f"Path not allowed: {path}"
                }
            
            if not os.path.exists(path):
                return {
                    "success": False,
                    "error": f"Directory not found: {path}"
                }
            
            items = []
            for item in os.listdir(path):
                item_path = os.path.join(path, item)
                items.append({
                    "name": item,
                    "type": "directory" if os.path.isdir(item_path) else "file",
                    "size": os.path.getsize(item_path) if os.path.isfile(item_path) else None
                })
            
            return {
                "success": True,
                "path": path,
                "items": items
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def install_package(self, package: str, manager: Optional[str] = None) -> Dict[str, Any]:
        """パッケージをインストール"""
        try:
            if not manager:
                # デフォルトのパッケージマネージャーを判定
                if shutil.which("yum"):
                    manager = "yum"
                elif shutil.which("apt-get"):
                    manager = "apt-get"
                else:
                    manager = "pip"
            
            commands = {
                "yum": f"sudo yum install -y {package}",
                "apt-get": f"sudo apt-get install -y {package}",
                "pip": f"pip install {package}",
                "pip3": f"pip3 install {package}",
                "npm": f"npm install {package}"
            }
            
            if manager not in commands:
                return {
                    "success": False,
                    "error": f"Unknown package manager: {manager}"
                }
            
            command = commands[manager]
            return self.execute_command(command)
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def manage_service(self, service: str, action: str) -> Dict[str, Any]:
        """サービスを管理"""
        try:
            valid_actions = ["start", "stop", "restart", "status", "enable", "disable"]
            if action not in valid_actions:
                return {
                    "success": False,
                    "error": f"Invalid action: {action}"
                }
            
            command = f"sudo systemctl {action} {service}"
            return self.execute_command(command)
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_system_info(self) -> Dict[str, Any]:
        """システム情報を取得"""
        try:
            info = {}
            
            # OS情報
            if os.path.exists("/etc/os-release"):
                with open("/etc/os-release", "r") as f:
                    for line in f:
                        if "=" in line:
                            key, value = line.strip().split("=", 1)
                            info[key] = value.strip('"')
            
            # カーネル情報
            uname = os.uname()
            info["kernel"] = uname.release
            info["hostname"] = uname.nodename
            info["architecture"] = uname.machine
            
            # メモリ情報
            if os.path.exists("/proc/meminfo"):
                with open("/proc/meminfo", "r") as f:
                    for line in f:
                        if line.startswith("MemTotal:"):
                            info["memory_total"] = line.split()[1]
                        elif line.startswith("MemAvailable:"):
                            info["memory_available"] = line.split()[1]
            
            return {
                "success": True,
                "info": info
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }

if __name__ == "__main__":
    # MCPサーバを起動
    server = MCPServerExtended("mcp_config.json")
    print("MCP Server Extended is running...")
    
    # ここに実際のMCPプロトコル処理を実装
    # JSON-RPCリクエストを受け取り、適切なメソッドを呼び出す

EOF

chmod +x scripts/mcp_server.py

# 5. systemdサービス作成（オプション）
echo "[5/5] systemdサービス設定..."
sudo cat > /etc/systemd/system/mcp-server.service << EOF
[Unit]
Description=MCP Server Extended
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/mcp-server-extended
ExecStart=/usr/bin/python3 $HOME/mcp-server-extended/scripts/mcp_server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mcp-server

echo "========================================="
echo "セットアップ完了！"
echo ""
echo "サーバー起動:"
echo "  sudo systemctl start mcp-server"
echo ""
echo "ステータス確認:"
echo "  sudo systemctl status mcp-server"
echo "========================================="
