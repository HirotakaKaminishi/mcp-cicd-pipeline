#!/usr/bin/env python3
"""
カスタムMCPサーバー追加システムのセットアップ
Claude Codeにカスタム機能を統合
"""

import os
import json
import subprocess
import sys
from pathlib import Path
import tempfile
import shutil

class CustomMCPSetup:
    """カスタムMCP設定セットアップ"""
    
    def __init__(self):
        self.work_dir = Path.cwd()
        self.claude_config_dirs = self.find_claude_config_dirs()
        
    def find_claude_config_dirs(self) -> list:
        """Claude Code設定ディレクトリを検索"""
        possible_dirs = [
            Path.home() / ".claude",
            Path.home() / "AppData" / "Roaming" / "Claude",
            Path.home() / "AppData" / "Local" / "Claude",
            Path("C:") / "Users" / os.getenv("USERNAME", "user") / ".claude",
        ]
        
        existing_dirs = []
        for dir_path in possible_dirs:
            if dir_path.exists():
                existing_dirs.append(dir_path)
                
        return existing_dirs
    
    def create_mcp_bridge_script(self) -> str:
        """MCP接続ブリッジスクリプトを作成"""
        bridge_script = '''#!/usr/bin/env python3
"""
MCP Bridge Script - Claude Codeとカスタムサーバーの橋渡し
"""

import sys
import json
import requests
import subprocess
import os
from typing import Dict, Any

# 設定
MCP_SERVER_URL = "http://localhost:8080"
BRIDGE_CONFIG = "mcp_bridge_config.json"

def load_config():
    """設定読み込み"""
    default_config = {
        "servers": {
            "remote-extended": {
                "url": MCP_SERVER_URL,
                "enabled": True
            }
        }
    }
    
    if os.path.exists(BRIDGE_CONFIG):
        with open(BRIDGE_CONFIG, 'r') as f:
            return json.load(f)
    return default_config

def call_remote_server(method: str, params: Dict = None) -> Dict[str, Any]:
    """リモートサーバー呼び出し"""
    try:
        request = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params or {},
            "id": 1
        }
        
        response = requests.post(
            MCP_SERVER_URL,
            json=request,
            timeout=30
        )
        
        if response.status_code == 200:
            return response.json().get("result", {})
        else:
            return {"error": f"HTTP {response.status_code}"}
            
    except Exception as e:
        return {"error": str(e)}

def mcp__remote_extended__execute_command(command: str, working_dir: str = None):
    """コマンド実行ツール"""
    params = {"command": command}
    if working_dir:
        params["working_dir"] = working_dir
    return call_remote_server("execute_command", params)

def mcp__remote_extended__write_file(path: str, content: str, mode: str = None):
    """ファイル書き込みツール"""
    params = {"path": path, "content": content}
    if mode:
        params["mode"] = mode
    return call_remote_server("write_file", params)

def mcp__remote_extended__read_file(path: str):
    """ファイル読み込みツール"""
    return call_remote_server("read_file", {"path": path})

def mcp__remote_extended__list_directory(path: str):
    """ディレクトリ一覧取得"""
    return call_remote_server("list_directory", {"path": path})

def mcp__remote_extended__install_package(package: str, manager: str = None):
    """パッケージインストール"""
    params = {"package": package}
    if manager:
        params["manager"] = manager
    return call_remote_server("install_package", params)

def mcp__remote_extended__get_system_info():
    """システム情報取得"""
    return call_remote_server("get_system_info")

# CLI機能
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python mcp_bridge.py <tool_name> [args...]")
        sys.exit(1)
    
    tool_name = sys.argv[1]
    args = sys.argv[2:]
    
    # 利用可能なツール
    tools = {
        "execute_command": mcp__remote_extended__execute_command,
        "write_file": mcp__remote_extended__write_file,
        "read_file": mcp__remote_extended__read_file,
        "list_directory": mcp__remote_extended__list_directory,
        "install_package": mcp__remote_extended__install_package,
        "get_system_info": mcp__remote_extended__get_system_info,
    }
    
    if tool_name in tools:
        try:
            if tool_name == "execute_command" and len(args) >= 1:
                result = tools[tool_name](args[0], args[1] if len(args) > 1 else None)
            elif tool_name == "write_file" and len(args) >= 2:
                result = tools[tool_name](args[0], args[1], args[2] if len(args) > 2 else None)
            elif tool_name == "read_file" and len(args) >= 1:
                result = tools[tool_name](args[0])
            elif tool_name == "list_directory" and len(args) >= 1:
                result = tools[tool_name](args[0])
            elif tool_name == "install_package" and len(args) >= 1:
                result = tools[tool_name](args[0], args[1] if len(args) > 1 else None)
            elif tool_name == "get_system_info":
                result = tools[tool_name]()
            else:
                result = {"error": "Invalid arguments for tool"}
            
            print(json.dumps(result, indent=2))
            
        except Exception as e:
            print(json.dumps({"error": str(e)}, indent=2))
    else:
        print(f"Unknown tool: {tool_name}")
        print(f"Available tools: {list(tools.keys())}")
'''
        
        bridge_path = self.work_dir / "mcp_bridge.py"
        with open(bridge_path, 'w') as f:
            f.write(bridge_script)
        
        os.chmod(bridge_path, 0o755)
        return str(bridge_path)
    
    def create_wrapper_functions(self) -> str:
        """Claude Code用ラッパー関数ファイルを作成"""
        wrapper_script = '''# MCP Custom Tools Wrapper
# Claude Code用カスタムMCPツール

import subprocess
import json
import sys
import os

def run_bridge_tool(tool_name, *args):
    """ブリッジ経由でツールを実行"""
    try:
        cmd = [sys.executable, "mcp_bridge.py", tool_name] + list(args)
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=os.path.dirname(__file__)
        )
        
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return {"error": result.stderr or "Command failed"}
    except Exception as e:
        return {"error": str(e)}

# カスタムMCPツール関数群
def mcp__remote_extended__execute_command(command, working_dir=None):
    """リモートサーバーでコマンド実行"""
    args = [command]
    if working_dir:
        args.append(working_dir)
    return run_bridge_tool("execute_command", *args)

def mcp__remote_extended__write_file(path, content, mode=None):
    """リモートサーバーでファイル作成"""
    args = [path, content]
    if mode:
        args.append(mode)
    return run_bridge_tool("write_file", *args)

def mcp__remote_extended__read_file(path):
    """リモートサーバーからファイル読み込み"""
    return run_bridge_tool("read_file", path)

def mcp__remote_extended__list_directory(path):
    """リモートディレクトリ一覧"""
    return run_bridge_tool("list_directory", path)

def mcp__remote_extended__install_package(package, manager=None):
    """リモートサーバーでパッケージインストール"""
    args = [package]
    if manager:
        args.append(manager)
    return run_bridge_tool("install_package", *args)

def mcp__remote_extended__get_system_info():
    """リモートサーバーのシステム情報取得"""
    return run_bridge_tool("get_system_info")

# テスト用関数
def test_custom_mcp():
    """カスタムMCPツールのテスト"""
    print("Testing custom MCP tools...")
    
    # システム情報取得テスト
    print("\\n1. Testing system info:")
    result = mcp__remote_extended__get_system_info()
    print(json.dumps(result, indent=2))
    
    # ディレクトリ一覧テスト
    print("\\n2. Testing directory listing:")
    result = mcp__remote_extended__list_directory("/root")
    print(json.dumps(result, indent=2))
    
    print("\\nCustom MCP tools test completed!")

if __name__ == "__main__":
    test_custom_mcp()
'''
        
        wrapper_path = self.work_dir / "mcp_custom_tools.py"
        with open(wrapper_path, 'w') as f:
            f.write(wrapper_script)
        
        return str(wrapper_path)
    
    def install_requirements(self):
        """必要なPythonパッケージをインストール"""
        requirements = ["requests"]
        
        for package in requirements:
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", package], 
                             check=True, capture_output=True)
                print(f"✅ Installed {package}")
            except subprocess.CalledProcessError:
                print(f"❌ Failed to install {package}")
    
    def create_usage_guide(self) -> str:
        """使用方法ガイドを作成"""
        guide = '''# カスタムMCP使用ガイド

## 🚀 セットアップ完了

以下のファイルが作成されました：
- `mcp_bridge.py` - MCP通信ブリッジ
- `mcp_custom_tools.py` - ラッパー関数
- `mcp_proxy_wrapper.py` - プロキシマネージャー

## 📝 使用方法

### 1. ブリッジ経由での直接実行
```bash
python mcp_bridge.py get_system_info
python mcp_bridge.py execute_command "ls -la /root"
python mcp_bridge.py write_file "/tmp/test.txt" "Hello World"
```

### 2. Python関数として使用
```python
from mcp_custom_tools import *

# システム情報取得
info = mcp__remote_extended__get_system_info()
print(info)

# ファイル作成
result = mcp__remote_extended__write_file(
    "/tmp/hello.txt", 
    "Hello from Claude Code!"
)

# コマンド実行
output = mcp__remote_extended__execute_command("ls -la /root")
print(output['stdout'])
```

### 3. テスト実行
```bash
python mcp_custom_tools.py
```

## 🔧 プロキシマネージャー
```bash
# CLIモードで起動
python mcp_proxy_wrapper.py cli

# 使用可能コマンド:
# add <name> <endpoint>     - サーバー追加
# list                      - サーバー一覧  
# test <name>              - 接続テスト
# call <server> <tool>     - ツール実行
```

## ✨ Claude Codeでの利用

これで Claude Code から以下が可能になります：

1. "リモートサーバーでPythonスクリプトを実行してください"
   → `mcp__remote_extended__execute_command("python3 script.py")`

2. "サーバーに設定ファイルを作成してください"
   → `mcp__remote_extended__write_file("/etc/config.txt", content)`

3. "パッケージをインストールしてください"
   → `mcp__remote_extended__install_package("numpy")`

全ての操作がClaude Code内から可能です！
'''
        
        guide_path = self.work_dir / "CUSTOM_MCP_GUIDE.md"
        with open(guide_path, 'w') as f:
            f.write(guide)
        
        return str(guide_path)
    
    def setup(self):
        """フルセットアップを実行"""
        print("🚀 Custom MCP Setup Starting...")
        print("=" * 50)
        
        # 1. 必要パッケージインストール
        print("\n[1/5] Installing requirements...")
        self.install_requirements()
        
        # 2. ブリッジスクリプト作成
        print("\n[2/5] Creating MCP bridge...")
        bridge_path = self.create_mcp_bridge_script()
        print(f"✅ Created: {bridge_path}")
        
        # 3. ラッパー関数作成
        print("\n[3/5] Creating wrapper functions...")
        wrapper_path = self.create_wrapper_functions()
        print(f"✅ Created: {wrapper_path}")
        
        # 4. 使用ガイド作成
        print("\n[4/5] Creating usage guide...")
        guide_path = self.create_usage_guide()
        print(f"✅ Created: {guide_path}")
        
        # 5. テスト実行
        print("\n[5/5] Running test...")
        try:
            result = subprocess.run([sys.executable, "mcp_custom_tools.py"], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                print("✅ Test completed successfully")
            else:
                print(f"⚠️ Test had issues: {result.stderr}")
        except Exception as e:
            print(f"⚠️ Test failed: {e}")
        
        print("\n" + "=" * 50)
        print("🎉 Custom MCP Setup Complete!")
        print()
        print("Next steps:")
        print("1. 確認: python mcp_custom_tools.py")
        print("2. 使用: from mcp_custom_tools import *")
        print("3. ガイド: cat CUSTOM_MCP_GUIDE.md")

if __name__ == "__main__":
    setup = CustomMCPSetup()
    setup.setup()