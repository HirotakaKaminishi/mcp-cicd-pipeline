#!/bin/bash

# GitHub Actions Self-hosted Runner Setup for MCP Server
# This script sets up a self-hosted runner on the MCP server

set -e

echo "🚀 GitHub Actions Self-hosted Runner Setup for MCP Server"
echo "=========================================================="

# Configuration
GITHUB_TOKEN=""
GITHUB_REPO="HirotakaKaminishi/mcp-cicd-pipeline"
RUNNER_VERSION="2.319.1"
RUNNER_NAME="mcp-server-runner"
RUNNER_LABELS="mcp-server,linux,x64,self-hosted"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root"
    exit 1
fi

echo "📋 Step 1: Installing dependencies..."
if command -v yum &> /dev/null; then
    yum update -y
    yum install -y curl tar gzip git nodejs npm
elif command -v apt &> /dev/null; then
    apt update
    apt install -y curl tar gzip git nodejs npm
fi

echo "📋 Step 2: Creating runner user..."
if ! id "actions-runner" &>/dev/null; then
    useradd -m -s /bin/bash actions-runner
    usermod -aG sudo actions-runner
fi

echo "📋 Step 3: Setting up runner directory..."
RUNNER_DIR="/home/actions-runner/actions-runner"
mkdir -p $RUNNER_DIR
cd $RUNNER_DIR

echo "📋 Step 4: Downloading GitHub Actions runner..."
curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz -L \
    https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

echo "📋 Step 5: Extracting runner..."
tar xzf actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

echo "📋 Step 6: Setting permissions..."
chown -R actions-runner:actions-runner /home/actions-runner
chmod +x $RUNNER_DIR/config.sh
chmod +x $RUNNER_DIR/run.sh

echo "📋 Step 7: Installing runner dependencies..."
sudo -u actions-runner bash -c "cd $RUNNER_DIR && ./bin/installdependencies.sh"

echo "📋 Step 8: Getting registration token..."
if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  GitHub token not provided. Manual configuration required."
    echo ""
    echo "🔧 Manual setup steps:"
    echo "1. Go to: https://github.com/$GITHUB_REPO/settings/actions/runners"
    echo "2. Click 'New self-hosted runner'"
    echo "3. Select Linux x64"
    echo "4. Copy the registration token"
    echo "5. Run the following as actions-runner user:"
    echo ""
    echo "   sudo -u actions-runner bash -c \"cd $RUNNER_DIR && ./config.sh --url https://github.com/$GITHUB_REPO --token YOUR_TOKEN --name $RUNNER_NAME --labels $RUNNER_LABELS --unattended\""
    echo "   sudo -u actions-runner bash -c \"cd $RUNNER_DIR && ./run.sh\""
    echo ""
else
    # Get registration token using GitHub API
    REG_TOKEN=$(curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/repos/$GITHUB_REPO/actions/runners/registration-token | \
        grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$REG_TOKEN" ]; then
        echo "📋 Step 9: Configuring runner..."
        sudo -u actions-runner bash -c "cd $RUNNER_DIR && ./config.sh --url https://github.com/$GITHUB_REPO --token $REG_TOKEN --name $RUNNER_NAME --labels $RUNNER_LABELS --unattended"
        
        echo "📋 Step 10: Installing as service..."
        cd $RUNNER_DIR
        ./svc.sh install actions-runner
        ./svc.sh start
        
        echo "✅ Self-hosted runner setup completed!"
        echo "🔍 Check status: ./svc.sh status"
    else
        echo "❌ Failed to get registration token"
        exit 1
    fi
fi

echo ""
echo "📋 Step 11: Creating MCP integration scripts..."

# Create MCP deployment script for runner
cat > /home/actions-runner/mcp-deploy-runner.sh << 'EOF'
#!/bin/bash

# MCP Deployment Script for GitHub Actions Runner
# This script runs on the self-hosted runner to deploy to MCP server

set -e

echo "🚀 Starting deployment from GitHub Actions Runner to MCP Server"

# Configuration
MCP_SERVER_URL="${MCP_SERVER_URL:-http://localhost:8080}"
DEPLOY_PATH="${DEPLOY_PATH:-/root/mcp_project}"
PROJECT_NAME="${PROJECT_NAME:-github-actions-deploy}"
COMMIT_SHA="${GITHUB_SHA:-unknown}"

# Function to call MCP API
call_mcp_api() {
    local method="$1"
    local params="$2"
    
    curl -X POST "$MCP_SERVER_URL" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" \
        --connect-timeout 10 \
        --max-time 30
}

# Test MCP server connectivity
echo "🔍 Testing MCP server connectivity..."
if ! call_mcp_api "get_system_info" "{}"; then
    echo "❌ Cannot connect to MCP server at $MCP_SERVER_URL"
    exit 1
fi

echo "✅ MCP server connected successfully"

# Create deployment directory
RELEASE_DIR="$DEPLOY_PATH/releases/$(date +%Y%m%d_%H%M%S)"
echo "📦 Creating deployment directory: $RELEASE_DIR"

call_mcp_api "execute_command" "{\"command\":\"mkdir -p $RELEASE_DIR\"}"

# Deploy application files
echo "📂 Deploying application files..."
for file in dist/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "📝 Deploying: $filename"
        
        # Read file content and deploy via MCP
        content=$(cat "$file" | base64 -w 0)
        call_mcp_api "write_file" "{\"path\":\"$RELEASE_DIR/$filename\",\"content\":\"$(echo -n "$content" | base64 -d)\"}"
    fi
done

# Create version file
echo "📋 Creating version file..."
call_mcp_api "write_file" "{\"path\":\"$RELEASE_DIR/version.txt\",\"content\":\"Deployment $COMMIT_SHA\\nTimestamp: $(date)\\nDeployed by: GitHub Actions\"}"

# Update current symlink
echo "🔗 Updating current deployment symlink..."
call_mcp_api "execute_command" "{\"command\":\"rm -f $DEPLOY_PATH/current && ln -sfn $RELEASE_DIR $DEPLOY_PATH/current\"}"

# Restart services
echo "🔄 Restarting application services..."
call_mcp_api "manage_service" "{\"service\":\"mcp-app\",\"action\":\"restart\"}"

# Log deployment
LOG_ENTRY="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ): Deployment successful - $COMMIT_SHA (GitHub Actions)"
call_mcp_api "execute_command" "{\"command\":\"echo '$LOG_ENTRY' >> $DEPLOY_PATH/deployment.log\"}"

echo "🎉 Deployment completed successfully!"
echo "📊 Release: $RELEASE_DIR"
echo "📝 Commit: $COMMIT_SHA"

EOF

chmod +x /home/actions-runner/mcp-deploy-runner.sh
chown actions-runner:actions-runner /home/actions-runner/mcp-deploy-runner.sh

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Configure GitHub repository secrets:"
echo "   - MCP_SERVER_URL: http://192.168.111.200:8080"
echo "   - DEPLOY_PATH: /root/mcp_project"
echo ""
echo "2. Update GitHub Actions workflow to use self-hosted runner:"
echo "   runs-on: [self-hosted, mcp-server]"
echo ""
echo "3. The runner will automatically start on system boot"
echo "4. Check runner status: sudo -u actions-runner bash -c 'cd $RUNNER_DIR && ./svc.sh status'"
echo ""
echo "🔗 GitHub Repository: https://github.com/$GITHUB_REPO"
echo "🖥️  Runner Name: $RUNNER_NAME"
echo "🏷️  Labels: $RUNNER_LABELS"