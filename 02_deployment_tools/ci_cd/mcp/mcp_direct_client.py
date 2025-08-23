#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Direct MCP Client for GitHub Actions Runner Status Check
"""

import requests
import json
import sys

def send_mcp_request(method, params=None):
    """Send MCP request to the server"""
    url = "http://192.168.111.200:8080"
    
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params or {},
        "id": 1
    }
    
    headers = {
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        return response.json() if response.status_code == 200 else None
    except Exception as e:
        print(f"Error: {str(e)}")
        return None

def check_server_capabilities():
    """Check what tools are available"""
    print("=== Checking Server Capabilities ===")
    
    # Try to list available tools
    result = send_mcp_request("tools/list")
    
    if not result:
        print("Failed to get tools list. Trying alternative methods...")
        
        # Try execute_command directly
        print("\n=== Testing execute_command ===")
        result = send_mcp_request("tools/call", {
            "name": "execute_command",
            "arguments": {
                "command": "whoami && hostname && uname -a"
            }
        })

def main():
    print("MCP Server Direct Connection Test")
    print("Server: http://192.168.111.200:8080")
    print("="*50)
    
    check_server_capabilities()

if __name__ == "__main__":
    main()