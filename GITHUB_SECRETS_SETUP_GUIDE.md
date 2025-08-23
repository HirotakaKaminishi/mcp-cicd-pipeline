# 🔐 GitHub Secrets Configuration Guide

## Overview
This guide explains how to configure the necessary GitHub Actions secrets for the hybrid CI/CD system to function properly.

## Required Secrets

### 1. MCP_DOCKER_SSH_KEY
**Purpose**: SSH private key for deployment to the MCP server  
**Location**: Repository Settings → Secrets and Variables → Actions

**Value**: Copy the entire content of the SSH private key from `auth_organized/keys_configs/mcp_docker_key`

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
[... full SSH private key content ...]
-----END OPENSSH PRIVATE KEY-----
```

### 2. SSH_PRIVATE_KEY (Already exists)
**Purpose**: Alternative SSH key for existing deployment workflow  
**Status**: ✅ Already configured in repository

## Configuration Steps

### Step 1: Access GitHub Repository Settings
1. Navigate to https://github.com/HirotakaKaminishi/mcp-cicd-pipeline
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and Variables** → **Actions**

### Step 2: Add MCP_DOCKER_SSH_KEY Secret
1. Click **New repository secret**
2. **Name**: `MCP_DOCKER_SSH_KEY`
3. **Value**: Copy the entire SSH private key content from the file
4. Click **Add secret**

### Step 3: Verify Existing Secrets
Ensure these secrets are present:
- ✅ SSH_PRIVATE_KEY
- ✅ MCP_DOCKER_SSH_KEY (newly added)

## Deployment Strategy Environment Variables

The hybrid system supports three deployment strategies:

### Available Strategies
- **`dual`**: Deploy using both MCP API and SSH methods (recommended)
- **`mcp-api`**: Deploy using MCP API only (legacy method)
- **`ssh-docker`**: Deploy using SSH + Docker Compose only (modern method)

### Configuration in Workflow
The deployment strategy is configured in the workflow environment variables:

```yaml
env:
  DEPLOY_STRATEGY: ${{ github.event.inputs.deploy_strategy || 'dual' }}
```

## Workflow Activation

### Manual Deployment
1. Go to **Actions** tab in GitHub repository
2. Select **Enhanced Hybrid CI/CD Pipeline** workflow
3. Click **Run workflow**
4. Choose deployment strategy:
   - Select `dual` for maximum reliability
   - Select `mcp-api` for legacy deployment only  
   - Select `ssh-docker` for modern containerized deployment only

### Automatic Deployment
The workflow automatically triggers on:
- Push to `main`, `develop`, or `hybrid-integration` branches
- Pull requests to `main` branch

## Security Notes

### SSH Key Security
- The SSH private key is stored securely as a GitHub secret
- Never commit SSH private keys to the repository
- The key is only accessible to GitHub Actions runners

### Access Control
- Only repository administrators can view/modify secrets
- Secrets are masked in workflow logs
- Use principle of least privilege

## Verification

After configuration, verify the setup:

1. **Check Secrets**: Ensure all required secrets are present
2. **Test Workflow**: Run a manual deployment to verify functionality
3. **Monitor Logs**: Check workflow logs for successful secret usage

## Troubleshooting

### Common Issues
1. **SSH Key Format**: Ensure the entire key including headers/footers is copied
2. **Permissions**: Verify the SSH key has proper permissions on the target server
3. **Secret Names**: Ensure secret names match exactly (case-sensitive)

### Verification Commands
```bash
# Test SSH connection (run locally)
ssh -i auth_organized/keys_configs/mcp_docker_key root@192.168.111.200

# Verify deployment directories exist
ssh root@192.168.111.200 "ls -la /root/mcp_project /var/deployment"
```

## Next Steps

After configuring secrets:
1. Push the `hybrid-integration` branch to GitHub
2. Create a pull request to merge into `main`
3. Test the hybrid deployment workflow
4. Monitor system performance and reliability

---

**Last Updated**: 2025-08-23  
**Required for**: Hybrid CI/CD Pipeline v2.0