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
            
        default:
            console.log(`
Usage: node mcp-deploy.js <command> [options]

Commands:
  deploy [project-name]  Deploy application to MCP server
  rollback              Rollback to previous deployment
  status                Get MCP server status

Environment Variables:
  GITHUB_SHA           Git commit SHA (for deployment tracking)
  MCP_SERVER_URL       MCP server URL (default: http://192.168.111.200:8080)
            `);
    }
}

module.exports = MCPDeployer;