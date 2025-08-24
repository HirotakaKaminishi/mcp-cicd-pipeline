#!/bin/bash

# MCP Configuration Deployment Script
# Deploys MCP client configurations for both original and new Docker-based servers

echo "🔧 Starting MCP Configuration Deployment..."

# Create configuration directory
mkdir -p /root/mcp-config
mkdir -p /home/$USER/.mcp 2>/dev/null || true

# Deploy main MCP configuration
cat > /root/mcp-config/.mcp.json << 'EOF'
{
  "servers": {
    "remote-extended": {
      "command": "npx",
      "args": [
        "-y", 
        "@anthropic-ai/mcp-client-stdio", 
        "http://192.168.111.200:8080"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    },
    "remote-new": {
      "command": "npx",
      "args": [
        "-y", 
        "@anthropic-ai/mcp-client-stdio", 
        "http://192.168.111.200:8081"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
EOF

# Test MCP servers connectivity
echo "🧪 Testing MCP server connectivity..."

# Test original MCP server (port 8080)
if curl -X POST http://192.168.111.200:8080 \
   -H "Content-Type: application/json" \
   -d '{"jsonrpc": "2.0", "method": "execute_command", "params": {"command": "echo \"MCP Original Server Test\""}, "id": 1}' \
   --connect-timeout 10 --silent > /dev/null; then
  echo "✅ MCP Original Server (8080) is responding"
else
  echo "❌ MCP Original Server (8080) is not responding"
fi

# Test new MCP server (port 8081)
if curl -f http://192.168.111.200:8081/health --connect-timeout 10 --silent > /dev/null; then
  echo "✅ MCP New Server (8081) is responding"
else
  echo "⚠️ MCP New Server (8081) is not responding (may still be starting)"
fi

# Set up systemd service for MCP configuration management
cat > /etc/systemd/system/mcp-config.service << 'EOF'
[Unit]
Description=MCP Configuration Management
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "MCP Configuration is ready"'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mcp-config.service
systemctl start mcp-config.service

echo "🎉 MCP Configuration deployment completed!"
echo "📁 Configuration file: /root/mcp-config/.mcp.json"
echo "🔗 Original MCP Server: http://192.168.111.200:8080"
echo "🔗 New MCP Server: http://192.168.111.200:8081"