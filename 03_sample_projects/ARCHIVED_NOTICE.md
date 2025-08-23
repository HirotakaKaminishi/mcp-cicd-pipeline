# Sample Projects Archive Notice

⚠️ **IMPORTANT**: This directory contained sample projects that caused Git submodule conflicts in GitHub Actions.

## What Happened
- Original sample projects contained nested Git repositories
- This caused persistent `Git exit code 128` errors in CI/CD workflows
- Projects have been archived to resolve GitHub Actions issues

## Original Content
The following projects were previously available:

### 1. archived/sample-project
- Legacy Node.js sample application  
- Contains deployment scripts and CI/CD configurations
- **Preserved in commit history before removal**

### 2. node_apps/  
- Node.js sample applications
- Express.js examples and templates
- **Preserved in commit history before removal**

### 3. react_apps/
- React application samples
- Vite-based modern React setup
- **Active development moved to `/mcp-cicd-pipeline/` directory**

## Current Status
- ✅ GitHub Actions workflows now run without Git errors
- ✅ CI/CD pipelines operate cleanly  
- ✅ All code preserved in Git history
- ✅ Active React development continues in main project structure

## Accessing Historical Code
To access the removed sample projects:
```bash
# View the last commit before removal
git show 695e675:03_sample_projects/

# Checkout historical version if needed
git checkout 695e675 -- 03_sample_projects/
```

---
*This notice created to document the resolution of GitHub Actions Git exit code 128 errors*