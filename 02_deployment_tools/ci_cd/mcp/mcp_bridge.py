#!/usr/bin/env python3
"""
MCP Bridge Script - Claude Code�ƃJ�X�^���T�[�o�[�̋��n��
"""

import sys
import json
import requests
import subprocess
import os
from typing import Dict, Any

# �ݒ�
MCP_SERVER_URL = "http://localhost:8080"
BRIDGE_CONFIG = "mcp_bridge_config.json"

def load_config():
    """�ݒ�ǂݍ���"""
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
    """�����[�g�T�[�o�[�Ăяo��"""
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
    """�R�}���h���s�c�[��"""
    params = {"command": command}
    if working_dir:
        params["working_dir"] = working_dir
    return call_remote_server("execute_command", params)

def mcp__remote_extended__write_file(path: str, content: str, mode: str = None):
    """�t�@�C���������݃c�[��"""
    params = {"path": path, "content": content}
    if mode:
        params["mode"] = mode
    return call_remote_server("write_file", params)

def mcp__remote_extended__read_file(path: str):
    """�t�@�C���ǂݍ��݃c�[��"""
    return call_remote_server("read_file", {"path": path})

def mcp__remote_extended__list_directory(path: str):
    """�f�B���N�g���ꗗ�擾"""
    return call_remote_server("list_directory", {"path": path})

def mcp__remote_extended__install_package(package: str, manager: str = None):
    """�p�b�P�[�W�C���X�g�[��"""
    params = {"package": package}
    if manager:
        params["manager"] = manager
    return call_remote_server("install_package", params)

def mcp__remote_extended__get_system_info():
    """�V�X�e�����擾"""
    return call_remote_server("get_system_info")

# CLI�@�\
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python mcp_bridge.py <tool_name> [args...]")
        sys.exit(1)
    
    tool_name = sys.argv[1]
    args = sys.argv[2:]
    
    # ���p�\�ȃc�[��
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
