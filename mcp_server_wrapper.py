#!/usr/bin/env python3
"""
MCP Server Wrapper - HTTP to STDIO Bridge
Bridges HTTP MCP server to STDIO for Claude integration
"""

import sys
import json
import requests
import asyncio
import traceback
from typing import Dict, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MCPServerWrapper:
    def __init__(self, server_url: str = "http://192.168.111.200:8080"):
        self.server_url = server_url.rstrip('/')
        self.session = requests.Session()
        self.session.timeout = 30
        
    def send_http_request(self, method: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        """Send HTTP request to MCP server using JSON-RPC format"""
        try:
            payload = {
                "jsonrpc": "2.0",
                "method": method,
                "params": params or {},
                "id": 1
            }
            
            response = self.session.post(
                self.server_url,
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                result = response.json()
                if "result" in result:
                    return {"result": result["result"]}
                elif "error" in result:
                    return {"error": result["error"]}
                else:
                    return {"result": result}
            else:
                return {"error": f"HTTP {response.status_code}: {response.text}"}
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Request failed: {e}")
            return {"error": f"Connection error: {str(e)}"}
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return {"error": f"Unexpected error: {str(e)}"}
    
    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle MCP request and convert to HTTP call"""
        method = request.get("method")
        params = request.get("params", {})
        request_id = request.get("id", 1)
        
        logger.debug(f"Handling request: {method} with params: {params}")
        
        # Map MCP methods to HTTP endpoints
        if method == "initialize":
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {
                            "listChanged": True
                        },
                        "resources": {
                            "listChanged": True
                        },
                        "prompts": {
                            "listChanged": True
                        }
                    },
                    "serverInfo": {
                        "name": "mcp-server-extended",
                        "version": "1.0.0"
                    }
                }
            }
        elif method == "tools/list":
            # Return available tools based on actual remote server capabilities
            return {
                "jsonrpc": "2.0", 
                "id": request_id,
                "result": {
                    "tools": [
                        {
                            "name": "execute_command",
                            "description": "Execute shell commands on remote server",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "command": {"type": "string", "description": "Command to execute"}
                                },
                                "required": ["command"],
                                "additionalProperties": False
                            }
                        },
                        {
                            "name": "read_file",
                            "description": "Read file contents from remote server",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "path": {"type": "string", "description": "File path to read"}
                                },
                                "required": ["path"],
                                "additionalProperties": False
                            }
                        },
                        {
                            "name": "write_file",
                            "description": "Write file contents to remote server",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "path": {"type": "string", "description": "File path to write"},
                                    "content": {"type": "string", "description": "Content to write"}
                                },
                                "required": ["path", "content"],
                                "additionalProperties": False
                            }
                        },
                        {
                            "name": "list_directory",
                            "description": "List directory contents on remote server",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "path": {"type": "string", "description": "Directory path to list"}
                                },
                                "required": ["path"],
                                "additionalProperties": False
                            }
                        },
                        {
                            "name": "get_system_info",
                            "description": "Get system information from remote server",
                            "inputSchema": {
                                "type": "object",
                                "properties": {},
                                "additionalProperties": False
                            }
                        },
                        {
                            "name": "manage_service",
                            "description": "Manage services on remote server",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "service": {"type": "string", "description": "Service name"},
                                    "action": {"type": "string", "description": "Action to perform (start/stop/restart/status)"}
                                },
                                "required": ["service", "action"],
                                "additionalProperties": False
                            }
                        }
                    ]
                }
            }
        elif method == "prompts/list":
            # Return available prompts (MCP tools as prompts for auto-completion)
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "prompts": [
                        {
                            "name": "get_system_info",
                            "description": "Get system information from remote server",
                            "arguments": []
                        },
                        {
                            "name": "execute_command",
                            "description": "Execute shell commands on remote server", 
                            "arguments": [
                                {
                                    "name": "command",
                                    "description": "Command to execute",
                                    "required": True
                                }
                            ]
                        },
                        {
                            "name": "read_file",
                            "description": "Read file contents from remote server",
                            "arguments": [
                                {
                                    "name": "path", 
                                    "description": "File path to read",
                                    "required": True
                                }
                            ]
                        },
                        {
                            "name": "write_file",
                            "description": "Write file contents to remote server",
                            "arguments": [
                                {
                                    "name": "path",
                                    "description": "File path to write", 
                                    "required": True
                                },
                                {
                                    "name": "content",
                                    "description": "Content to write",
                                    "required": True
                                }
                            ]
                        },
                        {
                            "name": "list_directory",
                            "description": "List directory contents on remote server",
                            "arguments": [
                                {
                                    "name": "path",
                                    "description": "Directory path to list",
                                    "required": True
                                }
                            ]
                        },
                        {
                            "name": "manage_service",
                            "description": "Manage services on remote server",
                            "arguments": [
                                {
                                    "name": "service",
                                    "description": "Service name",
                                    "required": True
                                },
                                {
                                    "name": "action", 
                                    "description": "Action to perform (start/stop/restart/status)",
                                    "required": True
                                }
                            ]
                        }
                    ]
                }
            }
        elif method == "prompts/get":
            # Handle both metadata retrieval and execution
            prompt_name = params.get("name")
            prompt_args = params.get("arguments", {})
            
            # If arguments are provided, this is an execution request
            if prompt_args is not None and isinstance(prompt_args, dict):
                # Execute the prompt and return results with messages
                if prompt_name == "execute_command":
                    result = self.send_http_request("execute_command", {"command": prompt_args.get("command", "")})
                elif prompt_name == "read_file":
                    result = self.send_http_request("read_file", {"path": prompt_args.get("path", "")})
                elif prompt_name == "write_file":
                    result = self.send_http_request("write_file", {"path": prompt_args.get("path", ""), "content": prompt_args.get("content", "")})
                elif prompt_name == "list_directory":
                    result = self.send_http_request("list_directory", {"path": prompt_args.get("path", "/")})
                elif prompt_name == "get_system_info":
                    result = self.send_http_request("get_system_info", {})
                elif prompt_name == "manage_service":
                    result = self.send_http_request("manage_service", {"service": prompt_args.get("service", ""), "action": prompt_args.get("action", "")})
                else:
                    result = {"error": f"Unknown prompt: {prompt_name}"}
                
                # Format result for execution response
                if isinstance(result, dict) and "result" in result:
                    result_data = result["result"]
                    if isinstance(result_data, dict):
                        content_text = json.dumps(result_data, indent=2, ensure_ascii=False)
                    else:
                        content_text = str(result_data)
                elif isinstance(result, dict) and "error" in result:
                    content_text = f"❌ Error: {result['error']}"
                else:
                    content_text = str(result)
                    
                return {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": {
                        "messages": [
                            {
                                "role": "assistant",
                                "content": {
                                    "type": "text",
                                    "text": content_text
                                }
                            }
                        ]
                    }
                }
            else:
                # Return prompt metadata only
                prompts_map = {
                    "get_system_info": {
                        "name": "get_system_info",
                        "description": "Get system information from remote server",
                        "arguments": []
                    },
                    "execute_command": {
                        "name": "execute_command", 
                        "description": "Execute shell commands on remote server",
                        "arguments": [
                            {
                                "name": "command",
                                "description": "Command to execute",
                                "required": True
                            }
                        ]
                    },
                    "read_file": {
                        "name": "read_file",
                        "description": "Read file contents from remote server", 
                        "arguments": [
                            {
                                "name": "path",
                                "description": "File path to read",
                                "required": True
                            }
                        ]
                    },
                    "write_file": {
                        "name": "write_file",
                        "description": "Write file contents to remote server",
                        "arguments": [
                            {
                                "name": "path",
                                "description": "File path to write",
                                "required": True
                            },
                            {
                                "name": "content", 
                                "description": "Content to write",
                                "required": True
                            }
                        ]
                    },
                    "list_directory": {
                        "name": "list_directory",
                        "description": "List directory contents on remote server",
                        "arguments": [
                            {
                                "name": "path",
                                "description": "Directory path to list", 
                                "required": True
                            }
                        ]
                    },
                    "manage_service": {
                        "name": "manage_service",
                        "description": "Manage services on remote server",
                        "arguments": [
                            {
                                "name": "service",
                                "description": "Service name",
                                "required": True
                            },
                            {
                                "name": "action",
                                "description": "Action to perform (start/stop/restart/status)",
                                "required": True
                            }
                        ]
                    }
                }
                
                if prompt_name in prompts_map:
                    return {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "result": prompts_map[prompt_name]
                    }
                else:
                    return {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {"code": -32602, "message": f"Unknown prompt: {prompt_name}"}
                    }
        elif method == "prompts/call":
            # Handle prompt execution by calling corresponding tool
            prompt_name = params.get("name")
            prompt_args = params.get("arguments", {})
            
            # Execute the corresponding tool directly
            if prompt_name == "execute_command":
                result = self.send_http_request("execute_command", {"command": prompt_args.get("command", "")})
            elif prompt_name == "read_file":
                result = self.send_http_request("read_file", {"path": prompt_args.get("path", "")})
            elif prompt_name == "write_file":
                result = self.send_http_request("write_file", {"path": prompt_args.get("path", ""), "content": prompt_args.get("content", "")})
            elif prompt_name == "list_directory":
                result = self.send_http_request("list_directory", {"path": prompt_args.get("path", "/")})
            elif prompt_name == "get_system_info":
                result = self.send_http_request("get_system_info", {})
            elif prompt_name == "manage_service":
                result = self.send_http_request("manage_service", {"service": prompt_args.get("service", ""), "action": prompt_args.get("action", "")})
            else:
                result = self.send_http_request(prompt_name, prompt_args)
            
            # Format result for MCP prompt response (needs "messages" array)
            if isinstance(result, dict) and "result" in result:
                result_data = result["result"]
                if isinstance(result_data, dict):
                    content_text = json.dumps(result_data, indent=2, ensure_ascii=False)
                else:
                    content_text = str(result_data)
            elif isinstance(result, dict) and "error" in result:
                content_text = f"❌ Error: {result['error']}"
            else:
                content_text = str(result)
                
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "messages": [
                        {
                            "role": "assistant",
                            "content": {
                                "type": "text",
                                "text": content_text
                            }
                        }
                    ]
                }
            }
        elif method == "resources/list":
            # Return available resources (empty for now)
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "resources": []
                }
            }
        elif method == "notifications/initialized":
            # Handle initialized notification (no response needed)
            logger.debug("Received initialized notification")
            return None
        elif method == "tools/call":
            tool_name = params.get("name")
            tool_args = params.get("arguments", {})
            
            # Convert tool calls to HTTP requests
            if tool_name == "execute_command":
                result = self.send_http_request("execute_command", {"command": tool_args.get("command", "")})
            elif tool_name == "read_file":
                result = self.send_http_request("read_file", {"path": tool_args.get("path", "")})
            elif tool_name == "write_file":
                result = self.send_http_request("write_file", {"path": tool_args.get("path", ""), "content": tool_args.get("content", "")})
            elif tool_name == "list_directory":
                result = self.send_http_request("list_directory", {"path": tool_args.get("path", "/")})
            elif tool_name == "get_system_info":
                result = self.send_http_request("get_system_info", {})
            elif tool_name == "manage_service":
                result = self.send_http_request("manage_service", {"service": tool_args.get("service", ""), "action": tool_args.get("action", "")})
            else:
                result = self.send_http_request(tool_name, tool_args)
            
            # Format result properly for MCP
            if isinstance(result, dict) and "result" in result:
                result_data = result["result"]
                if isinstance(result_data, dict):
                    content = json.dumps(result_data, indent=2, ensure_ascii=False)
                else:
                    content = str(result_data)
            elif isinstance(result, dict) and "error" in result:
                content = f"❌ Error: {result['error']}"
            else:
                content = str(result)
                
            return {
                "jsonrpc": "2.0",
                "id": request_id, 
                "result": {"content": [{"type": "text", "text": content}]}
            }
        else:
            # Forward other requests directly
            result = self.send_http_request(method, params)
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": result
            }

def main():
    """Main STDIO loop"""
    wrapper = MCPServerWrapper()
    logger.info("MCP Server Wrapper started")
    
    try:
        while True:
            line = sys.stdin.readline()
            if not line:
                break
                
            line = line.strip()
            if not line:
                continue
                
            try:
                request = json.loads(line)
                response = wrapper.handle_request(request)
                if response is not None:
                    print(json.dumps(response), flush=True)
            except json.JSONDecodeError as e:
                logger.error(f"JSON decode error: {e}")
                error_response = {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": "Parse error"}
                }
                print(json.dumps(error_response), flush=True)
            except Exception as e:
                logger.error(f"Error processing request: {e}")
                logger.error(traceback.format_exc())
                error_response = {
                    "jsonrpc": "2.0", 
                    "id": None,
                    "error": {"code": -32603, "message": f"Internal error: {str(e)}"}
                }
                print(json.dumps(error_response), flush=True)
                
    except KeyboardInterrupt:
        logger.info("Wrapper interrupted")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        logger.error(traceback.format_exc())
        
if __name__ == "__main__":
    main()