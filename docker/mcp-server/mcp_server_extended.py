#!/usr/bin/env python3
"""
MCP Server Extended - Enhanced HTTP Server Implementation for Docker
"""

import http.server
import socketserver
import json
import subprocess
import os
import signal
import sys
import threading
import time
import logging
import shutil
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/mcp/mcp_server.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class MCPHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        logger.info("%s - - [%s] %s" % (self.client_address[0], 
                                       self.log_date_time_string(), 
                                       format % args))

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)

        try:
            request = json.loads(post_data.decode('utf-8'))
            method = request.get('method', '')
            params = request.get('params', {})
            
            logger.info(f"Received request: {method}")

            if method == 'get_system_info':
                result = subprocess.run(['uname', '-a'], capture_output=True, text=True)
                result_data = {'system': result.stdout.strip()}
                
            elif method == 'list_directory':
                path = params.get('path', '/')
                try:
                    files = os.listdir(path)
                    result_data = {'files': files, 'path': path}
                except Exception as e:
                    result_data = {'error': f'Cannot list directory: {str(e)}'}
                    
            elif method == 'execute_command':
                command = params.get('command', '')
                logger.info(f"Executing command: {command}")
                try:
                    result = subprocess.run(
                        command, 
                        shell=True, 
                        capture_output=True, 
                        text=True, 
                        timeout=300,
                        cwd='/var/deployment'
                    )
                    result_data = {
                        'stdout': result.stdout, 
                        'stderr': result.stderr, 
                        'returncode': result.returncode
                    }
                except subprocess.TimeoutExpired:
                    result_data = {'error': 'Command timeout', 'returncode': -1}
                except Exception as e:
                    result_data = {'error': str(e), 'returncode': -1}
                    
            elif method == 'read_file':
                file_path = params.get('path', '')
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    result_data = {'content': content, 'path': file_path}
                except Exception as e:
                    result_data = {'error': f'Cannot read file: {str(e)}'}
                    
            elif method == 'write_file':
                file_path = params.get('path', '')
                content = params.get('content', '')
                try:
                    os.makedirs(os.path.dirname(file_path), exist_ok=True)
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    result_data = {'success': True, 'path': file_path}
                except Exception as e:
                    result_data = {'error': f'Cannot write file: {str(e)}'}
                    
            elif method == 'manage_service':
                service = params.get('service', '')
                action = params.get('action', '')
                try:
                    if action in ['start', 'stop', 'restart', 'status']:
                        result = subprocess.run(
                            ['systemctl', action, service], 
                            capture_output=True, 
                            text=True
                        )
                        result_data = {
                            'stdout': result.stdout, 
                            'stderr': result.stderr, 
                            'returncode': result.returncode
                        }
                    else:
                        result_data = {'error': f'Invalid action: {action}'}
                except Exception as e:
                    result_data = {'error': str(e)}
                    
            elif method == 'deploy_application':
                app_name = params.get('app_name', '')
                source_path = params.get('source_path', '')
                try:
                    deployment_path = f'/var/deployment/{app_name}'
                    os.makedirs(deployment_path, exist_ok=True)
                    
                    # Copy application files
                    if os.path.exists(source_path):
                        shutil.copytree(source_path, deployment_path, dirs_exist_ok=True)
                    
                    result_data = {
                        'success': True, 
                        'deployment_path': deployment_path,
                        'app_name': app_name
                    }
                except Exception as e:
                    result_data = {'error': f'Deployment failed: {str(e)}'}
                    
            elif method == 'health_check':
                result_data = {
                    'status': 'healthy',
                    'timestamp': time.time(),
                    'services': {
                        'mcp_server': 'running',
                        'docker': 'available' if shutil.which('docker') else 'unavailable'
                    }
                }
                
            else:
                result_data = {'error': f'Unknown method: {method}'}

            response = {
                'jsonrpc': '2.0', 
                'id': request.get('id', 1), 
                'result': result_data
            }

            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode('utf-8'))

        except Exception as e:
            logger.error(f"Error processing request: {str(e)}")
            error_response = {
                'jsonrpc': '2.0', 
                'id': 1, 
                'error': {
                    'code': -32603, 
                    'message': str(e)
                }
            }
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(error_response).encode('utf-8'))

    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            health_info = {
                'status': 'MCP Server Extended is running',
                'version': '2.0',
                'timestamp': time.time()
            }
            self.wfile.write(json.dumps(health_info).encode('utf-8'))
        else:
            self.send_error(404)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

def signal_handler(signum, frame):
    logger.info("Shutting down MCP Server...")
    sys.exit(0)

def main():
    PORT = int(os.environ.get('MCP_SERVER_PORT', 8080))
    
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create required directories
    os.makedirs('/var/log/mcp', exist_ok=True)
    os.makedirs('/var/deployment', exist_ok=True)
    
    with socketserver.TCPServer(("", PORT), MCPHandler) as httpd:
        httpd.allow_reuse_address = True
        logger.info(f'MCP Server Extended running on port {PORT}')
        logger.info('Available methods: get_system_info, list_directory, execute_command, read_file, write_file, manage_service, deploy_application, health_check')
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Server interrupted")
        finally:
            httpd.server_close()

if __name__ == "__main__":
    main()