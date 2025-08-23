# 🤖 GitHub Actions CI/CD Setup Guide

Complete guide for setting up automated deployment using GitHub Actions.

## 📋 Prerequisites

- GitHub repository with this code
- MCP Server (192.168.111.200) with SSH access
- SSH key pair configured (`mcp_docker_key`)

## 🔧 Repository Setup

### 1. Create/Initialize Repository

```bash
# If not already a git repository
git init
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git

# Add all files
git add .
git commit -m "Initial Docker MCP Server setup"
git push -u origin main
```

### 2. GitHub Repository Settings

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Actions** → **General**  
3. Ensure "Allow all actions and reusable workflows" is selected
4. Enable "Read and write permissions" for GITHUB_TOKEN

## 🔐 Configure Secrets

### Required Secrets

Go to **Settings** → **Secrets and variables** → **Actions** and add:

#### 1. MCP_DOCKER_SSH_KEY

**Value:** The contents of your SSH private key

```bash
# On Windows (from project root)
type auth_organized\keys_configs\mcp_docker_key

# On Linux/macOS  
cat auth_organized/keys_configs/mcp_docker_key
```

**Copy the entire output including:**
```
-----BEGIN OPENSSH PRIVATE KEY-----
[key content]
-----END OPENSSH PRIVATE KEY-----
```

### Optional Secrets (for custom configurations)

#### 2. MCP_SERVER_HOST
- **Default:** 192.168.111.200
- **Description:** Target server IP address

#### 3. DEPLOY_PATH  
- **Default:** /var/deployment
- **Description:** Deployment directory on server

## 📁 Repository Structure

Ensure your repository has this structure:

```
/
├── .github/
│   └── workflows/
│       └── docker-deploy.yml     # GitHub Actions workflow
├── docker/                       # Docker configurations
│   ├── mcp-server/
│   │   ├── Dockerfile
│   │   └── mcp_server_extended.py
│   ├── nginx/
│   │   ├── Dockerfile
│   │   └── default.conf
│   ├── react-app/
│   │   ├── Dockerfile
│   │   └── package.json
│   └── deployment/
│       ├── Dockerfile  
│       └── package.json
├── 03_sample_projects/
│   └── react_apps/               # React application source
├── scripts/                      # Deployment scripts
│   ├── deploy.sh                 # Linux/macOS deployment
│   ├── deploy.bat                # Windows deployment  
│   └── README.md
├── auth_organized/
│   └── keys_configs/
│       ├── mcp_docker_key        # SSH private key
│       └── mcp_docker_key.pub    # SSH public key
├── docker-compose.yml            # Docker Compose configuration
├── README.md                     # Project documentation
└── GITHUB_ACTIONS_SETUP.md      # This file
```

## 🚀 Workflow Configuration

### Automatic Triggers

The workflow automatically runs on:

- **Push to main branch** → Full test + deploy
- **Push to develop branch** → Tests only
- **Pull request to main** → Tests only

### Manual Trigger

You can manually trigger deployment:

1. Go to **Actions** tab in GitHub
2. Select "Docker MCP Server CI/CD Pipeline"
3. Click "Run workflow"
4. Select branch and click "Run workflow"

## 📊 Workflow Steps

### Phase 1: Testing
- ✅ Checkout code
- ✅ Setup Node.js environment
- ✅ Install React dependencies
- ✅ Run React tests
- ✅ Lint code
- ✅ Test Docker builds

### Phase 2: Deployment (main branch only)  
- ✅ Setup SSH connection
- ✅ Copy files to server
- ✅ Build Docker images
- ✅ Deploy containers  
- ✅ Configure auto-start
- ✅ Verify health

### Phase 3: Notification
- ✅ Report deployment status
- ✅ Display service URLs

## 🔍 Monitoring Deployments

### GitHub Actions Interface

1. Go to **Actions** tab in your repository
2. Click on the latest workflow run
3. View logs for each step
4. Check deployment status and errors

### Server-Side Monitoring

```bash
# Check deployment status
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose ps"

# View live logs
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose logs -f"

# Test endpoints
curl http://192.168.111.200/health
curl http://192.168.111.200:8080
```

## 🛠 Troubleshooting

### Common Issues

#### 1. SSH Authentication Failed

**Error:** `Permission denied (publickey)`

**Solutions:**
```bash
# Verify SSH key is correct
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 "echo OK"

# Check key format in GitHub secrets (no extra spaces/newlines)
# Regenerate key if needed
ssh-keygen -t rsa -b 4096 -f auth_organized/keys_configs/mcp_docker_key -C "github-actions"
```

#### 2. Docker Build Failed

**Error:** `docker: command not found` or build errors

**Solutions:**
```bash
# Check Docker installation on server
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "docker --version && docker compose --version"

# Install Docker if missing
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "curl -fsSL https://get.docker.com | sh && systemctl start docker && systemctl enable docker"
```

#### 3. Port Already in Use

**Error:** `bind: address already in use`

**Solutions:**
```bash
# Stop conflicting services
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "systemctl stop nginx mcp-server && pkill -f node"

# Check what's using ports
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "netstat -tulpn | grep -E ':(80|8080|3000)'"
```

#### 4. Health Check Failed

**Error:** Health endpoints not responding

**Solutions:**
```bash
# Check container status
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose ps && docker compose logs nginx"

# Restart specific services
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose restart nginx mcp-server"
```

## 🔄 Rollback Procedures

### Automatic Rollback (if implemented)

```yaml
# Add to workflow for automatic rollback
- name: Rollback on failure
  if: failure()
  run: |
    ssh -i ~/.ssh/id_rsa root@${{ env.MCP_SERVER_HOST }} << 'EOF'
      cd ${{ env.DEPLOY_PATH }}
      docker compose down
      # Restore from backup if available
    EOF
```

### Manual Rollback

```bash
# SSH to server
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200

# Stop current deployment
cd /var/deployment
docker compose down

# If you have backups, restore them
# docker compose -f docker-compose.backup.yml up -d

# Or restart with clean build
docker compose build --no-cache
docker compose up -d
```

## 🎯 Best Practices

### Branch Strategy
- **main** → Production deployments
- **develop** → Development/staging  
- **feature/** → Feature branches (tests only)

### Commit Messages
```bash
git commit -m "feat: add user authentication"
git commit -m "fix: resolve Docker build issue"  
git commit -m "docs: update deployment guide"
```

### Testing Before Deploy
```bash
# Always test locally first
scripts/deploy.sh dev

# Then test the GitHub Actions workflow on a feature branch
git checkout -b test-deployment
git push origin test-deployment
# Check Actions tab for test results
```

### Security
- ✅ Never commit SSH private keys to repository
- ✅ Use GitHub Secrets for sensitive data
- ✅ Regularly rotate SSH keys
- ✅ Monitor deployment logs for suspicious activity

## 📈 Advanced Configuration

### Environment-Specific Deployments

Create multiple workflows for different environments:

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging
on:
  push:
    branches: [develop]
env:
  MCP_SERVER_HOST: "staging.example.com"
```

### Slack/Discord Notifications

Add notification steps:

```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Database Migrations

Add migration steps:

```yaml
- name: Run migrations
  run: |
    ssh root@${{ env.MCP_SERVER_HOST }} << 'EOF'
      cd /var/deployment
      docker compose exec mcp-server python manage.py migrate
    EOF
```