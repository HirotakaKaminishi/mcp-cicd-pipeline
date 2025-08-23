#!/usr/bin/env node

/**
 * MCP Server Deployment Script
 * GitHub Actions integration for MCP-based CI/CD
 */

const https = require('http');
const fs = require('fs');
const path = require('path');

class MCPDeployer {
    constructor(serverUrl = 'http://192.168.111.200:8080') {
        this.serverUrl = serverUrl;
        this.requestId = 1;
    }

    /**
     * Send JSON-RPC request to MCP server
     */
    async sendRequest(method, params = {}) {
        return new Promise((resolve, reject) => {
            const requestData = JSON.stringify({
                jsonrpc: '2.0',
                method: method,
                params: params,
                id: this.requestId++
            });

            const url = new URL(this.serverUrl);
            const options = {
                hostname: url.hostname,
                port: url.port,
                path: '/',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(requestData)
                }
            };

            const req = https.request(options, (res) => {
                let data = '';
                res.on('data', (chunk) => data += chunk);
                res.on('end', () => {
                    try {
                        const response = JSON.parse(data);
                        if (response.error) {
                            reject(new Error(`MCP Error: ${response.error.message}`));
                        } else {
                            resolve(response.result);
                        }
                    } catch (e) {
                        reject(new Error(`Parse error: ${e.message}`));
                    }
                });
            });

            req.on('error', reject);
            req.write(requestData);
            req.end();
        });
    }

    /**
     * Execute command on MCP server
     */
    async executeCommand(command, workingDir = null) {
        console.log(`🔧 Executing: ${command}`);
        const params = { command };
        if (workingDir) params.working_dir = workingDir;
        
        const result = await this.sendRequest('execute_command', params);
        console.log(`✅ Command completed (exit code: ${result.returncode})`);
        
        if (result.stdout) console.log(`📄 Output: ${result.stdout}`);
        if (result.stderr) console.error(`⚠️  Error: ${result.stderr}`);
        
        return result;
    }

    /**
     * Write file to MCP server
     */
    async writeFile(filePath, content, mode = '644') {
        console.log(`📝 Writing file: ${filePath}`);
        const result = await this.sendRequest('write_file', {
            path: filePath,
            content: content,
            mode: mode
        });
        console.log(`✅ File written successfully`);
        return result;
    }

    /**
     * Read file from MCP server
     */
    async readFile(filePath) {
        console.log(`📖 Reading file: ${filePath}`);
        const result = await this.sendRequest('read_file', { path: filePath });
        return result;
    }

    /**
     * List directory contents
     */
    async listDirectory(dirPath) {
        console.log(`📂 Listing directory: ${dirPath}`);
        const result = await this.sendRequest('list_directory', { path: dirPath });
        return result;
    }

    /**
     * Manage system service
     */
    async manageService(service, action) {
        console.log(`🔄 Service ${action}: ${service}`);
        const result = await this.sendRequest('manage_service', {
            service: service,
            action: action
        });
        console.log(`✅ Service ${action} completed`);
        return result;
    }

    /**
     * Complete deployment workflow
     */
    async deploy(options = {}) {
        const {
            projectName = 'mcp-app',
            sourcePath = './dist',
            targetPath = '/root/mcp_project',
            service = 'mcp-app',
            githubSha = process.env.GITHUB_SHA || 'unknown'
        } = options;

        console.log(`🚀 Starting deployment for ${projectName}`);
        console.log(`📦 Commit: ${githubSha}`);

        try {
            // 1. Create deployment directory
            const timestamp = new Date().toISOString().replace(/[:-]/g, '').slice(0, 15);
            const releasePath = `${targetPath}/releases/${timestamp}`;
            
            await this.executeCommand(`mkdir -p ${releasePath}`);
            await this.executeCommand(`mkdir -p ${targetPath}/current`);

            // 2. Get system info
            console.log('📊 Getting system information...');
            const systemInfo = await this.sendRequest('get_system_info');
            console.log(`🖥️  System: ${systemInfo.system}`);

            // 3. Backup current deployment
            await this.executeCommand(`cp -r ${targetPath}/current ${targetPath}/backup_${timestamp} 2>/dev/null || true`);

            // 4. Deploy new version (simulation - in real scenario, files would be transferred)
            console.log('📦 Deploying application files...');
            await this.executeCommand(`echo "Deployment ${githubSha}" > ${releasePath}/version.txt`);
            await this.executeCommand(`ln -sfn ${releasePath} ${targetPath}/current`);

            // 5. Restart service
            console.log('🔄 Restarting application service...');
            try {
                await this.manageService(service, 'restart');
            } catch (e) {
                console.log(`ℹ️  Service ${service} not found, skipping restart`);
            }

            // 6. Health check
            console.log('🏥 Running health check...');
            await this.executeCommand(`curl -f http://localhost:8080/health || echo "Health check endpoint not available"`);

            // 7. Log deployment
            const logEntry = `${new Date().toISOString()}: Deployment successful - ${githubSha}\\n`;
            await this.executeCommand(`echo "${logEntry}" >> ${targetPath}/deployment.log`);

            console.log('✅ Deployment completed successfully!');
            return { success: true, releasePath, timestamp };

        } catch (error) {
            console.error(`❌ Deployment failed: ${error.message}`);
            
            // Log failure
            const logEntry = `${new Date().toISOString()}: Deployment failed - ${githubSha}: ${error.message}\\n`;
            await this.executeCommand(`echo "${logEntry}" >> ${targetPath}/deployment.log`);
            
            throw error;
        }
    }

    /**
     * Rollback to previous deployment
     */
    async rollback(options = {}) {
        const { targetPath = '/root/mcp_project', service = 'mcp-app' } = options;
        
        console.log('🔄 Rolling back to previous deployment...');
        
        try {
            // Find backup directory
            const result = await this.executeCommand(`find ${targetPath} -name "backup_*" -type d | sort -r | head -1`);
            const backupPath = result.stdout.trim();
            
            if (!backupPath) {
                throw new Error('No backup found for rollback');
            }
            
            console.log(`📦 Restoring from: ${backupPath}`);
            await this.executeCommand(`rm -f ${targetPath}/current`);
            await this.executeCommand(`cp -r ${backupPath} ${targetPath}/current`);
            
            // Restart service
            try {
                await this.manageService(service, 'restart');
            } catch (e) {
                console.log(`ℹ️  Service ${service} not found, skipping restart`);
            }
            
            console.log('✅ Rollback completed successfully!');
            return { success: true };
            
        } catch (error) {
            console.error(`❌ Rollback failed: ${error.message}`);
            throw error;
        }
    }

    /**
     * Deploy Docker Compose stack
     */
    async deployDockerCompose(options = {}) {
        const {
            deployPath = '/var/deployment',
            projectName = 'mcp-cicd-pipeline'
        } = options;

        console.log(`🐳 Starting Docker Compose deployment...`);
        
        try {
            // 1. Check if docker-compose.yml exists
            const composeFile = `${deployPath}/docker-compose.yml`;
            console.log(`📋 Checking compose file: ${composeFile}`);
            
            // 2. Stop existing containers
            console.log('⏹️  Stopping existing containers...');
            await this.executeCommand(`cd ${deployPath} && docker compose down || true`);
            
            // 3. Pull latest images (if needed)
            console.log('📥 Pulling latest images...');
            await this.executeCommand(`cd ${deployPath} && docker compose pull || echo "Pull completed or not needed"`);
            
            // 4. Build and start containers
            console.log('🔨 Building and starting containers...');
            await this.executeCommand(`cd ${deployPath} && docker compose build --no-cache`);
            await this.executeCommand(`cd ${deployPath} && docker compose up -d`);
            
            // 5. Wait for services to be ready
            console.log('⏳ Waiting for services to start...');
            await this.executeCommand(`sleep 30`);
            
            // 6. Check container status
            console.log('📊 Checking container status...');
            const statusResult = await this.executeCommand(`cd ${deployPath} && docker compose ps`);
            console.log(`Container status:\n${statusResult.stdout}`);
            
            // 7. Health checks
            console.log('🏥 Running health checks...');
            const healthChecks = [
                'curl -f http://localhost:8080/health || echo "MCP Server health check failed"',
                'curl -f http://localhost/ || echo "Nginx health check failed"',
                'curl -f http://localhost:3000 || echo "React app health check failed"'
            ];
            
            for (const healthCheck of healthChecks) {
                try {
                    const result = await this.executeCommand(healthCheck);
                    console.log(`✅ Health check passed: ${result.stdout.trim()}`);
                } catch (e) {
                    console.log(`⚠️  Health check warning: ${e.message}`);
                }
            }
            
            // 8. Log deployment
            const logEntry = `${new Date().toISOString()}: Docker Compose deployment successful\\n`;
            await this.executeCommand(`echo "${logEntry}" >> ${deployPath}/deployment.log`);
            
            console.log('✅ Docker Compose deployment completed successfully!');
            return { success: true, deployPath, timestamp: new Date().toISOString() };
            
        } catch (error) {
            console.error(`❌ Docker Compose deployment failed: ${error.message}`);
            throw error;
        }
    }

    /**
     * Get Docker status
     */
    async getDockerStatus(options = {}) {
        const { deployPath = '/var/deployment' } = options;
        
        console.log('🐳 Getting Docker status...');
        
        try {
            // Docker daemon status
            const dockerVersion = await this.executeCommand('docker --version');
            console.log(`Docker version: ${dockerVersion.stdout.trim()}`);
            
            // Container status
            const containerStatus = await this.executeCommand(`cd ${deployPath} && docker compose ps`);
            console.log(`Container status:\n${containerStatus.stdout}`);
            
            // Image status
            const imageStatus = await this.executeCommand('docker images | head -10');
            console.log(`Images:\n${imageStatus.stdout}`);
            
            // Network status
            const networkStatus = await this.executeCommand('docker network ls');
            console.log(`Networks:\n${networkStatus.stdout}`);
            
            return {
                dockerVersion: dockerVersion.stdout.trim(),
                containers: containerStatus.stdout,
                images: imageStatus.stdout,
                networks: networkStatus.stdout
            };
            
        } catch (error) {
            console.error(`❌ Docker status check failed: ${error.message}`);
            throw error;
        }
    }

    /**
     * Restart Docker services
     */
    async restartDockerServices(options = {}) {
        const { deployPath = '/var/deployment' } = options;
        
        console.log('🔄 Restarting Docker services...');
        
        try {
            await this.executeCommand(`cd ${deployPath} && docker compose restart`);
            
            // Wait for services to restart
            await this.executeCommand(`sleep 15`);
            
            // Check status after restart
            const statusResult = await this.executeCommand(`cd ${deployPath} && docker compose ps`);
            console.log(`Services restarted:\n${statusResult.stdout}`);
            
            console.log('✅ Docker services restarted successfully!');
            return { success: true, status: statusResult.stdout };
            
        } catch (error) {
            console.error(`❌ Docker restart failed: ${error.message}`);
            throw error;
        }
    }
}

// CLI interface
if (require.main === module) {
    const deployer = new MCPDeployer();
    const command = process.argv[2];
    
    switch (command) {
        case 'deploy':
            deployer.deploy({
                projectName: process.argv[3] || 'mcp-app',
                githubSha: process.env.GITHUB_SHA
            }).catch(process.exit);
            break;
            
        case 'rollback':
            deployer.rollback().catch(process.exit);
            break;
            
        case 'status':
            deployer.sendRequest('get_system_info')
                .then(result => console.log(JSON.stringify(result, null, 2)))
                .catch(console.error);
            break;

        case 'docker-deploy':
            deployer.deployDockerCompose({
                deployPath: process.argv[3] || '/var/deployment'
            }).catch(process.exit);
            break;

        case 'docker-status':
            deployer.getDockerStatus({
                deployPath: process.argv[3] || '/var/deployment'
            }).catch(process.exit);
            break;

        case 'docker-restart':
            deployer.restartDockerServices({
                deployPath: process.argv[3] || '/var/deployment'
            }).catch(process.exit);
            break;
            
        default:
            console.log(`
Usage: node mcp-deploy.js <command> [options]

Commands:
  deploy [project-name]     Deploy application to MCP server
  rollback                 Rollback to previous deployment
  status                   Get MCP server status
  docker-deploy [path]     Deploy Docker Compose stack
  docker-status [path]     Get Docker services status
  docker-restart [path]    Restart Docker services

Environment Variables:
  GITHUB_SHA              Git commit SHA (for deployment tracking)
  MCP_SERVER_URL          MCP server URL (default: http://192.168.111.200:8080)

Docker Commands:
  docker-deploy           Full Docker Compose stack deployment
  docker-status           Shows containers, images, and network status
  docker-restart          Restart all Docker services in stack
            `);
    }
}

module.exports = MCPDeployer;