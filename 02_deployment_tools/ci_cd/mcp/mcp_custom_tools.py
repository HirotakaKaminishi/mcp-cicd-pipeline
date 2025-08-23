# MCP Custom Tools Wrapper
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
    print("\n1. Testing system info:")
    result = mcp__remote_extended__get_system_info()
    print(json.dumps(result, indent=2))
    
    # ディレクトリ一覧テスト
    print("\n2. Testing directory listing:")
    result = mcp__remote_extended__list_directory("/root")
    print(json.dumps(result, indent=2))
    
    print("\nCustom MCP tools test completed!")

if __name__ == "__main__":
    test_custom_mcp()
