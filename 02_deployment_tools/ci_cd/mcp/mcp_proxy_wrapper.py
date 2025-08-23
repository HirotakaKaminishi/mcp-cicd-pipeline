#!/usr/bin/env python3
"""
MCP Proxy Wrapper
Claude CodeにカスタムMCPサーバー追加機能を提供するプロキシシステム
"""

import json
import subprocess
import requests
import time
import os
import sys
from typing import Dict, Any, List, Optional
from pathlib import Path
import tempfile
import threading
import queue
import signal

class MCPProxyWrapper:
    """MCPプロキシラッパークラス"""
    
    def __init__(self, config_file: str = "mcp_proxy_config.json"):
        self.config_file = config_file
        self.config = self.load_config()
        self.servers = {}
        self.running = False
        
    def load_config(self) -> Dict:
        """設定ファイルを読み込み"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    return json.load(f)
        except Exception as e:
            print(f"Config load error: {e}")
        
        # デフォルト設定
        return {
            "servers": {
                "remote-extended": {
                    "endpoint": "http://localhost:8080",
                    "type": "http",
                    "enabled": True,
                    "tools": [
                        "execute_command",
                        "write_file", 
                        "read_file",
                        "list_directory",
                        "install_package",
                        "manage_service",
                        "get_system_info"
                    ]
                }
            },
            "proxy_port": 9090
        }
    
    def save_config(self):
        """設定ファイルを保存"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            print(f"Config save error: {e}")
    
    def add_server(self, name: str, endpoint: str, server_type: str = "http", tools: List[str] = None) -> bool:
        """MCPサーバーを追加"""
        try:
            if tools is None:
                tools = ["get_system_info"]
            
            self.config["servers"][name] = {
                "endpoint": endpoint,
                "type": server_type,
                "enabled": True,
                "tools": tools
            }
            
            self.save_config()
            print(f"Added MCP server: {name} -> {endpoint}")
            return True
            
        except Exception as e:
            print(f"Error adding server {name}: {e}")
            return False
    
    def remove_server(self, name: str) -> bool:
        """MCPサーバーを削除"""
        try:
            if name in self.config["servers"]:
                del self.config["servers"][name]
                self.save_config()
                print(f"Removed MCP server: {name}")
                return True
            else:
                print(f"Server not found: {name}")
                return False
                
        except Exception as e:
            print(f"Error removing server {name}: {e}")
            return False
    
    def list_servers(self) -> Dict:
        """MCPサーバー一覧を取得"""
        return self.config.get("servers", {})
    
    def test_server(self, name: str) -> bool:
        """MCPサーバーの接続テスト"""
        try:
            if name not in self.config["servers"]:
                print(f"Server not found: {name}")
                return False
            
            server = self.config["servers"][name]
            endpoint = server["endpoint"]
            
            if server["type"] == "http":
                # HTTP接続テスト
                test_request = {
                    "jsonrpc": "2.0",
                    "method": "get_system_info",
                    "params": {},
                    "id": 1
                }
                
                response = requests.post(
                    endpoint,
                    json=test_request,
                    timeout=5
                )
                
                if response.status_code == 200:
                    print(f"✅ Server {name} is responding")
                    return True
                else:
                    print(f"❌ Server {name} returned status: {response.status_code}")
                    return False
            
        except Exception as e:
            print(f"❌ Server {name} connection failed: {e}")
            return False
    
    def call_tool(self, server_name: str, tool_name: str, params: Dict = None) -> Dict:
        """MCPツールを呼び出し"""
        try:
            if server_name not in self.config["servers"]:
                return {"error": f"Server not found: {server_name}"}
            
            server = self.config["servers"][server_name]
            
            if tool_name not in server.get("tools", []):
                return {"error": f"Tool {tool_name} not available on server {server_name}"}
            
            if not server.get("enabled", False):
                return {"error": f"Server {server_name} is disabled"}
            
            endpoint = server["endpoint"]
            
            request = {
                "jsonrpc": "2.0",
                "method": tool_name,
                "params": params or {},
                "id": int(time.time())
            }
            
            if server["type"] == "http":
                response = requests.post(
                    endpoint,
                    json=request,
                    timeout=30
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    return {"error": f"HTTP {response.status_code}: {response.text}"}
            
        except Exception as e:
            return {"error": f"Tool call failed: {e}"}
    
    def create_wrapper_tools(self):
        """Claude Code用のラッパーツールを作成"""
        wrapper_tools = {}
        
        for server_name, server_config in self.config["servers"].items():
            if not server_config.get("enabled", False):
                continue
                
            for tool_name in server_config.get("tools", []):
                wrapper_tool_name = f"mcp__{server_name}__{tool_name}"
                wrapper_tools[wrapper_tool_name] = {
                    "server": server_name,
                    "tool": tool_name,
                    "description": f"{tool_name} on {server_name}"
                }
        
        return wrapper_tools
    
    def execute_wrapper_tool(self, wrapper_tool_name: str, params: Dict = None) -> Dict:
        """ラッパーツールを実行"""
        try:
            # ツール名をパース
            if not wrapper_tool_name.startswith("mcp__"):
                return {"error": "Invalid wrapper tool name"}
            
            parts = wrapper_tool_name[5:].split("__")
            if len(parts) != 2:
                return {"error": "Invalid wrapper tool format"}
            
            server_name, tool_name = parts
            return self.call_tool(server_name, tool_name, params)
            
        except Exception as e:
            return {"error": f"Wrapper execution failed: {e}"}

def create_cli_interface():
    """CLIインターフェースを作成"""
    proxy = MCPProxyWrapper()
    
    print("=== MCP Proxy Wrapper CLI ===")
    print("Available commands:")
    print("  add <name> <endpoint> [tools]")
    print("  remove <name>")
    print("  list")
    print("  test <name>")
    print("  call <server> <tool> [params_json]")
    print("  exit")
    print()
    
    while True:
        try:
            command = input("mcp-proxy> ").strip().split()
            if not command:
                continue
                
            cmd = command[0].lower()
            
            if cmd == "exit":
                break
            elif cmd == "add" and len(command) >= 3:
                name, endpoint = command[1], command[2]
                tools = command[3].split(",") if len(command) > 3 else None
                proxy.add_server(name, endpoint, "http", tools)
            elif cmd == "remove" and len(command) >= 2:
                proxy.remove_server(command[1])
            elif cmd == "list":
                servers = proxy.list_servers()
                for name, config in servers.items():
                    status = "✅" if config.get("enabled") else "❌"
                    print(f"{status} {name}: {config['endpoint']} ({len(config.get('tools', []))} tools)")
            elif cmd == "test" and len(command) >= 2:
                proxy.test_server(command[1])
            elif cmd == "call" and len(command) >= 3:
                server_name, tool_name = command[1], command[2]
                params = json.loads(command[3]) if len(command) > 3 else {}
                result = proxy.call_tool(server_name, tool_name, params)
                print(json.dumps(result, indent=2))
            else:
                print("Invalid command or missing arguments")
                
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")
    
    print("Goodbye!")

# 使用可能なラッパーツール関数を動的に作成
def create_dynamic_wrapper_functions():
    """動的にラッパー関数を作成"""
    proxy = MCPProxyWrapper()
    wrapper_tools = proxy.create_wrapper_tools()
    
    # グローバル名前空間に関数を追加
    globals_dict = globals()
    
    for wrapper_name, tool_info in wrapper_tools.items():
        def make_wrapper_func(server_name, tool_name):
            def wrapper_func(**kwargs):
                return proxy.call_tool(server_name, tool_name, kwargs)
            wrapper_func.__name__ = f"{server_name}_{tool_name}"
            wrapper_func.__doc__ = f"Execute {tool_name} on {server_name}"
            return wrapper_func
        
        globals_dict[wrapper_name] = make_wrapper_func(
            tool_info["server"], 
            tool_info["tool"]
        )
    
    print(f"Created {len(wrapper_tools)} wrapper functions")
    return wrapper_tools

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "cli":
            create_cli_interface()
        elif sys.argv[1] == "create-wrappers":
            tools = create_dynamic_wrapper_functions()
            print("Available wrapper tools:")
            for name in tools.keys():
                print(f"  {name}()")
        else:
            print("Usage: python mcp_proxy_wrapper.py [cli|create-wrappers]")
    else:
        # デフォルトでプロキシを起動
        proxy = MCPProxyWrapper()
        print("MCP Proxy Wrapper initialized")
        print(f"Config file: {proxy.config_file}")
        print("Use 'python mcp_proxy_wrapper.py cli' for interactive mode")