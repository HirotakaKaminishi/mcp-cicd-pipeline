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
        """�ݒ�t�@�C����ǂݍ���"""
        if config_path and os.path.exists(config_path):
            with open(config_path, 'r') as f:
                return json.load(f)
        return {}
    
    def is_path_allowed(self, path: str) -> bool:
        """�p�X��������Ă��邩�m�F"""
        path = os.path.abspath(path)
        
        # ���ۃp�X�`�F�b�N
        for denied in self.security.get("denied_paths", []):
            if path.startswith(denied):
                return False
        
        # ���p�X�`�F�b�N
        for allowed in self.security.get("allowed_paths", []):
            if path.startswith(allowed):
                return True
        
        return False
    
    def is_command_allowed(self, command: str) -> bool:
        """�R�}���h��������Ă��邩�m�F"""
        cmd_parts = command.split()
        if not cmd_parts:
            return False
        
        base_cmd = cmd_parts[0]
        allowed_commands = self.security.get("allowed_commands", [])
        
        return base_cmd in allowed_commands
    
    def execute_command(self, command: str, working_dir: Optional[str] = None) -> Dict[str, Any]:
        """�R�}���h�����s"""
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
        """�t�@�C���ɏ�������"""
        try:
            if not self.is_path_allowed(path):
                return {
                    "success": False,
                    "error": f"Path not allowed: {path}"
                }
            
            # �f�B���N�g�������݂��Ȃ��ꍇ�͍쐬
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
        """�t�@�C����ǂݍ���"""
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
        """�f�B���N�g�����e���ꗗ�\��"""
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
        """�p�b�P�[�W���C���X�g�[��"""
        try:
            if not manager:
                # �f�t�H���g�̃p�b�P�[�W�}�l�[�W���[�𔻒�
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
        """�T�[�r�X���Ǘ�"""
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
        """�V�X�e�������擾"""
        try:
            info = {}
            
            # OS���
            if os.path.exists("/etc/os-release"):
                with open("/etc/os-release", "r") as f:
                    for line in f:
                        if "=" in line:
                            key, value = line.strip().split("=", 1)
                            info[key] = value.strip('"')
            
            # �J�[�l�����
            uname = os.uname()
            info["kernel"] = uname.release
            info["hostname"] = uname.nodename
            info["architecture"] = uname.machine
            
            # ���������
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
    # MCP�T�[�o���N��
    server = MCPServerExtended("mcp_config.json")
    print("MCP Server Extended is running...")
    
    # �����Ɏ��ۂ�MCP�v���g�R������������
    # JSON-RPC���N�G�X�g���󂯎��A�K�؂ȃ��\�b�h���Ăяo��
