# 🧪 GitHub Actions Deployment Test Guide

## 📋 Current Status
- ✅ **Docker containers**: 3/4 healthy (mcp-server, nginx, deployment-manager)
- ✅ **Service endpoints**: All responding correctly
- ✅ **SSH connectivity**: Working properly
- ✅ **Deployment scripts**: Ready and tested

## 🚀 GitHub Actions Test Procedure

### Step 1: Create GitHub Repository

1. **Create new repository on GitHub**
   ```
   Repository name: mcp-server-docker-cicd
   Description: Fully containerized MCP Server with Docker CI/CD pipeline
   Visibility: Private or Public (your choice)
   Initialize: Don't initialize (we have existing code)
   ```

2. **Add remote origin**
   ```bash
   cd C:\Users\hirotaka\Documents\work
   git remote add origin https://github.com/YOUR_USERNAME/mcp-server-docker-cicd.git
   ```

### Step 2: Configure GitHub Secrets

Go to **Repository Settings** → **Secrets and variables** → **Actions**

#### Required Secret: `MCP_DOCKER_SSH_KEY`
```bash
# Get the SSH private key content
cat auth_organized\keys_configs\mcp_docker_key
```

**Copy the entire output including the header and footer:**
```
-----BEGIN OPENSSH PRIVATE KEY-----
[key content here]
-----END OPENSSH PRIVATE KEY-----
```

**Important**: Ensure no extra spaces or line breaks when pasting into GitHub.

### Step 3: Push Code to Repository

```bash
# Push to GitHub (this will trigger the workflow)
git push -u origin main
```

### Step 4: Monitor GitHub Actions

1. Go to your repository on GitHub
2. Click on **"Actions"** tab
3. You should see **"Docker MCP Server CI/CD Pipeline"** workflow running

### Step 5: Expected Workflow Steps

#### Phase 1: Test (Always runs)
- ✅ Checkout code
- ✅ Setup Node.js environment  
- ✅ Install React dependencies
- ✅ Run React tests
- ✅ Lint code
- ✅ Test Docker builds

#### Phase 2: Deploy (Only on main branch)
- ✅ Setup SSH connection
- ✅ Copy deployment files
- ✅ Build Docker images on server
- ✅ Deploy with docker-compose
- ✅ Configure auto-start service
- ✅ Verify health endpoints

#### Phase 3: Notification
- ✅ Report deployment status
- ✅ Display service URLs

## 🔍 Verification After Deployment

### Automatic Verification (Built into workflow)
The workflow automatically tests these endpoints:
- `http://192.168.111.200/health`
- `http://192.168.111.200/service`  
- `http://192.168.111.200:8080`

### Manual Verification Commands

```bash
# Check container status via SSH
ssh -i auth_organized\keys_configs\mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose ps"

# Test all service endpoints
curl http://192.168.111.200/health
curl http://192.168.111.200/service
curl http://192.168.111.200:8080

# View deployment logs
ssh -i auth_organized\keys_configs\mcp_docker_key root@192.168.111.200 \
    "cd /var/deployment && docker compose logs --tail=20"
```

### Expected Results

#### Container Status
```
NAME                 STATUS
mcp-server           Up X minutes (healthy)
nginx-proxy          Up X minutes (healthy)  
deployment-manager   Up X minutes (healthy)
react-app            Up X minutes (healthy) [if fixed]
```

#### Health Endpoints
- **`/health`**: `{"status": "healthy", "service": "nginx-proxy", "timestamp": "..."}`
- **`/service`**: `{"status": "running", "services": ["nginx", "mcp-server"], "timestamp": "..."}`
- **`/8080`**: `{"status": "MCP Server Extended is running", "version": "2.0", ...}`

## 🛠 Troubleshooting

### Common Issues

#### 1. SSH Authentication Failed
```
Error: Permission denied (publickey)
```
**Solution**: 
- Verify SSH key in GitHub secrets has no extra spaces
- Test SSH connection manually: 
  ```bash
  ssh -i auth_organized\keys_configs\mcp_docker_key root@192.168.111.200 "echo OK"
  ```

#### 2. Docker Build Failed
```
Error: docker: command not found
```
**Solution**: 
- Verify Docker is installed on server:
  ```bash
  ssh -i auth_organized\keys_configs\mcp_docker_key root@192.168.111.200 \
      "docker --version && docker compose --version"
  ```

#### 3. Port Conflicts
```
Error: bind: address already in use
```
**Solution**: 
- The workflow automatically stops conflicting services
- Manual check: 
  ```bash
  ssh -i auth_organized\keys_configs\mcp_docker_key root@192.168.111.200 \
      "netstat -tulpn | grep -E ':(80|8080)'"
  ```

#### 4. Test Failures
```
Error: npm test failed
```
**Solution**: 
- Check React app tests locally:
  ```bash
  cd 03_sample_projects/react_apps
  npm test
  ```

### Workflow Debugging

1. **View Action Logs**: Go to Actions tab → Click on failed run → View logs
2. **SSH Debug**: Manually run deployment script:
   ```bash
   scripts\deploy.bat production
   ```
3. **Container Debug**: Check container logs on server:
   ```bash
   ssh -i auth_organized\keys_configs\mcp_docker_key root@192.168.111.200 \
       "cd /var/deployment && docker compose logs [service-name]"
   ```

## 🎯 Test Scenarios

### Test 1: Initial Deployment
1. Push code to main branch
2. Verify workflow completes successfully  
3. Check all services are healthy
4. Test all endpoints respond correctly

### Test 2: Code Changes
1. Make minor change to React app or documentation
2. Commit and push to main
3. Verify redeployment works correctly
4. Confirm services remain healthy during update

### Test 3: Branch Testing
1. Create feature branch: `git checkout -b feature/test-deployment`
2. Push to feature branch: `git push origin feature/test-deployment`
3. Verify only tests run (no deployment)
4. Create PR to main to trigger full workflow

### Test 4: Manual Workflow Trigger
1. Go to Actions tab in GitHub
2. Select "Docker MCP Server CI/CD Pipeline"
3. Click "Run workflow" → Select main branch → Run
4. Verify manual trigger works correctly

## ✅ Success Criteria

A successful GitHub Actions deployment test should achieve:

- ✅ **Workflow Completion**: All jobs complete without errors
- ✅ **Container Health**: All containers start and report healthy  
- ✅ **Service Availability**: All endpoints respond correctly
- ✅ **Auto-start Configuration**: systemd service configured for boot startup
- ✅ **Monitoring**: Deployment status logged correctly
- ✅ **Rollback Capability**: Previous deployment can be restored if needed

## 📊 Performance Metrics

Expected deployment times:
- **Test Phase**: ~3-5 minutes
- **Deploy Phase**: ~5-10 minutes  
- **Total Workflow**: ~8-15 minutes

Monitor these metrics during testing to ensure reasonable performance.

---

## 🚨 Ready to Test?

**Prerequisites Checklist**:
- ✅ GitHub repository created
- ✅ SSH key added to GitHub Secrets  
- ✅ Code pushed to main branch
- ✅ Server accessible at 192.168.111.200
- ✅ Docker running on server

**Execute**: `git push origin main` and monitor the Actions tab!

🎉 **Your fully automated Docker CI/CD pipeline is ready for testing!**