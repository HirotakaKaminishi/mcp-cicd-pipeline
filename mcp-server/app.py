#!/usr/bin/env python3
"""
MCP Server API Implementation
Provides all MCP tools via REST API endpoints
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import subprocess
import json
import shutil
from pathlib import Path
import psutil
import docker
from datetime import datetime
import logging

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Security configuration
ALLOWED_PATHS = [
    "/root/mcp_project",
    "/root/mcp_containers",
    "/var/www",
    "/tmp"
]

ALLOWED_COMMANDS = [
    "ls", "pwd", "cat", "echo", "grep", "find",
    "docker", "systemctl", "service", "ps", "netstat"
]

def is_path_allowed(path):
    """Check if path is allowed"""
    abs_path = os.path.abspath(path)
    return any(abs_path.startswith(allowed) for allowed in ALLOWED_PATHS)

def is_command_allowed(command):
    """Check if command is allowed"""
    cmd_parts = command.split()
    if not cmd_parts:
        return False
    return cmd_parts[0] in ALLOWED_COMMANDS

# Health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "MCP Server API",
        "version": "1.0.0"
    })

# File Operations
@app.route('/api/file/read', methods=['POST'])
def read_file():
    try:
        data = request.json
        path = data.get('path')
        
        if not is_path_allowed(path):
            return jsonify({"error": "Path not allowed"}), 403
        
        with open(path, 'r') as f:
            content = f.read()
        
        return jsonify({
            "success": True,
            "content": content,
            "path": path
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/file/write', methods=['POST'])
def write_file():
    try:
        data = request.json
        path = data.get('path')
        content = data.get('content', '')
        
        if not is_path_allowed(path):
            return jsonify({"error": "Path not allowed"}), 403
        
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(content)
        
        return jsonify({
            "success": True,
            "path": path,
            "size": len(content)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/file/delete', methods=['POST'])
def delete_file():
    try:
        data = request.json
        path = data.get('path')
        
        if not is_path_allowed(path):
            return jsonify({"error": "Path not allowed"}), 403
        
        if os.path.isfile(path):
            os.remove(path)
        elif os.path.isdir(path):
            shutil.rmtree(path)
        
        return jsonify({
            "success": True,
            "path": path
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/file/list', methods=['POST'])
def list_directory():
    try:
        data = request.json
        path = data.get('path', '/')
        
        if not is_path_allowed(path):
            return jsonify({"error": "Path not allowed"}), 403
        
        items = []
        for item in os.listdir(path):
            item_path = os.path.join(path, item)
            stat = os.stat(item_path)
            items.append({
                "name": item,
                "type": "directory" if os.path.isdir(item_path) else "file",
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()
            })
        
        return jsonify({
            "success": True,
            "path": path,
            "items": items
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# System Operations
@app.route('/api/system/execute', methods=['POST'])
def execute_command():
    try:
        data = request.json
        command = data.get('command')
        
        if not is_command_allowed(command):
            return jsonify({"error": "Command not allowed"}), 403
        
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        return jsonify({
            "success": True,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        })
    except subprocess.TimeoutExpired:
        return jsonify({"error": "Command timeout"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/system/info', methods=['GET'])
def get_system_info():
    try:
        return jsonify({
            "success": True,
            "hostname": os.uname().nodename,
            "platform": os.uname().sysname,
            "release": os.uname().release,
            "cpu_count": psutil.cpu_count(),
            "cpu_percent": psutil.cpu_percent(interval=1),
            "memory": {
                "total": psutil.virtual_memory().total,
                "available": psutil.virtual_memory().available,
                "percent": psutil.virtual_memory().percent
            },
            "disk": {
                "total": psutil.disk_usage('/').total,
                "used": psutil.disk_usage('/').used,
                "free": psutil.disk_usage('/').free,
                "percent": psutil.disk_usage('/').percent
            }
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Process Management
@app.route('/api/process/list', methods=['GET'])
def list_processes():
    try:
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'status', 'cpu_percent', 'memory_percent']):
            try:
                processes.append(proc.info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        return jsonify({
            "success": True,
            "processes": processes[:100]  # Limit to 100 processes
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/process/kill', methods=['POST'])
def kill_process():
    try:
        data = request.json
        pid = data.get('pid')
        
        process = psutil.Process(pid)
        process.terminate()
        
        return jsonify({
            "success": True,
            "pid": pid
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Docker Operations
@app.route('/api/docker/containers', methods=['GET'])
def list_containers():
    try:
        client = docker.from_env()
        containers = []
        
        for container in client.containers.list(all=True):
            containers.append({
                "id": container.short_id,
                "name": container.name,
                "image": container.image.tags[0] if container.image.tags else "unknown",
                "status": container.status,
                "ports": container.ports
            })
        
        return jsonify({
            "success": True,
            "containers": containers
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/docker/container/<container_id>/start', methods=['POST'])
def start_container(container_id):
    try:
        client = docker.from_env()
        container = client.containers.get(container_id)
        container.start()
        
        return jsonify({
            "success": True,
            "container_id": container_id,
            "status": "started"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/docker/container/<container_id>/stop', methods=['POST'])
def stop_container(container_id):
    try:
        client = docker.from_env()
        container = client.containers.get(container_id)
        container.stop()
        
        return jsonify({
            "success": True,
            "container_id": container_id,
            "status": "stopped"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/docker/container/<container_id>/logs', methods=['GET'])
def get_container_logs(container_id):
    try:
        client = docker.from_env()
        container = client.containers.get(container_id)
        logs = container.logs(tail=100).decode('utf-8')
        
        return jsonify({
            "success": True,
            "container_id": container_id,
            "logs": logs
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Service Management
@app.route('/api/service/<service_name>/status', methods=['GET'])
def get_service_status(service_name):
    try:
        result = subprocess.run(
            f"systemctl status {service_name}",
            shell=True,
            capture_output=True,
            text=True
        )
        
        return jsonify({
            "success": True,
            "service": service_name,
            "status": "active" if "active (running)" in result.stdout else "inactive",
            "output": result.stdout
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/service/<service_name>/restart', methods=['POST'])
def restart_service(service_name):
    try:
        if service_name not in ["nginx", "docker", "mcp-server"]:
            return jsonify({"error": "Service not allowed"}), 403
        
        result = subprocess.run(
            f"systemctl restart {service_name}",
            shell=True,
            capture_output=True,
            text=True
        )
        
        return jsonify({
            "success": True,
            "service": service_name,
            "action": "restarted"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)