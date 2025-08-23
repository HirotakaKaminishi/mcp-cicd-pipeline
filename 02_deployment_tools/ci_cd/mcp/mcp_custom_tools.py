# MCP Custom Tools Wrapper
# Claude Code�p�J�X�^��MCP�c�[��

import subprocess
import json
import sys
import os

def run_bridge_tool(tool_name, *args):
    """�u���b�W�o�R�Ńc�[�������s"""
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

# �J�X�^��MCP�c�[���֐��Q
def mcp__remote_extended__execute_command(command, working_dir=None):
    """�����[�g�T�[�o�[�ŃR�}���h���s"""
    args = [command]
    if working_dir:
        args.append(working_dir)
    return run_bridge_tool("execute_command", *args)

def mcp__remote_extended__write_file(path, content, mode=None):
    """�����[�g�T�[�o�[�Ńt�@�C���쐬"""
    args = [path, content]
    if mode:
        args.append(mode)
    return run_bridge_tool("write_file", *args)

def mcp__remote_extended__read_file(path):
    """�����[�g�T�[�o�[����t�@�C���ǂݍ���"""
    return run_bridge_tool("read_file", path)

def mcp__remote_extended__list_directory(path):
    """�����[�g�f�B���N�g���ꗗ"""
    return run_bridge_tool("list_directory", path)

def mcp__remote_extended__install_package(package, manager=None):
    """�����[�g�T�[�o�[�Ńp�b�P�[�W�C���X�g�[��"""
    args = [package]
    if manager:
        args.append(manager)
    return run_bridge_tool("install_package", *args)

def mcp__remote_extended__get_system_info():
    """�����[�g�T�[�o�[�̃V�X�e�����擾"""
    return run_bridge_tool("get_system_info")

# �e�X�g�p�֐�
def test_custom_mcp():
    """�J�X�^��MCP�c�[���̃e�X�g"""
    print("Testing custom MCP tools...")
    
    # �V�X�e�����擾�e�X�g
    print("\n1. Testing system info:")
    result = mcp__remote_extended__get_system_info()
    print(json.dumps(result, indent=2))
    
    # �f�B���N�g���ꗗ�e�X�g
    print("\n2. Testing directory listing:")
    result = mcp__remote_extended__list_directory("/root")
    print(json.dumps(result, indent=2))
    
    print("\nCustom MCP tools test completed!")

if __name__ == "__main__":
    test_custom_mcp()
