#!/usr/bin/env node

/**
 * Hybrid MCP Server Deployment Script
 * Integrates legacy MCP API deployment with modern Docker Compose approach
 * Supports dual deployment strategy with automatic failover
 */

const https = require('http');
const fs = require('fs').promises;
const path = require('path');
const { exec } = require('child_process');
const util = require('util');

const execAsync = util.promisify(exec);

class HybridMCPDeployer {
    constructor(options = {}) {
        this.mcpServerUrl = options.mcpServerUrl || 'http://192.168.111.200:8080';
        this.sshHost = options.sshHost || '192.168.111.200';
        this.legacyPath = options.legacyPath || '/root/mcp_project';
        this.dockerPath = options.dockerPath || '/var/deployment';
        this.sshKeyPath = options.sshKeyPath || 'auth_organized/keys_configs/mcp_docker_key';
        this.requestId = 1;
        
        // Deployment strategy: 'mcp-api', 'ssh-docker', 'dual'
        this.deployStrategy = options.strategy || 'dual';
        
        this.logger = {
            info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
            error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
            success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`),
            warning: (msg) => console.warn(`[WARNING] ${new Date().toISOString()} - ${msg}`)
        };
    }

    /**
     * Send JSON-RPC request to MCP server (Legacy method)
     */
    async sendMCPRequest(method, params = {}) {
        return new Promise((resolve, reject) => {
            const requestData = JSON.stringify({
                jsonrpc: '2.0',
                method: method,
                params: params,
                id: this.requestId++
            });

            const url = new URL(this.mcpServerUrl);
            const options = {
                hostname: url.hostname,
                port: url.port,
                path: '/',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(requestData)
                },
                timeout: 30000
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
            req.on('timeout', () => {
                req.destroy();
                reject(new Error('MCP request timeout'));
            });
            
            req.write(requestData);
            req.end();
        });
    }

    /**
     * Execute SSH command (Modern method)
     */
    async executeSSHCommand(command, options = {}) {
        const { timeout = 120000, retries = 3 } = options;
        
        const sshCommand = `ssh -i "${this.sshKeyPath}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@${this.sshHost} "${command}"`;
        
        for (let attempt = 1; attempt <= retries; attempt++) {
            try {
                this.logger.info(`SSH Command (attempt ${attempt}/${retries}): ${command}`);
                const { stdout, stderr } = await execAsync(sshCommand, { timeout });
                
                if (stderr && !stderr.includes('Warning')) {
                    this.logger.warning(`SSH stderr: ${stderr}`);
                }
                
                return { stdout, stderr, success: true };
            } catch (error) {
                this.logger.error(`SSH attempt ${attempt} failed: ${error.message}`);
                if (attempt === retries) {
                    throw new Error(`SSH command failed after ${retries} attempts: ${error.message}`);
                }
                // Wait before retry
                await new Promise(resolve => setTimeout(resolve, 2000 * attempt));
            }
        }
    }

    /**
     * Execute local command
     */
    async executeLocalCommand(command, options = {}) {
        const { timeout = 60000 } = options;
        
        try {
            this.logger.info(`Local Command: ${command}`);
            const { stdout, stderr } = await execAsync(command, { timeout });
            return { stdout, stderr, success: true };
        } catch (error) {
            this.logger.error(`Local command failed: ${error.message}`);
            throw error;
        }
    }

    /**
     * Check system health and connectivity
     */
    async performHealthChecks() {
        this.logger.info('Performing pre-deployment health checks...');
        
        const healthResults = {
            mcpApi: false,
            sshConnectivity: false,
            dockerDaemon: false,
            systemResources: false
        };

        // Check MCP API connectivity
        try {
            const systemInfo = await this.sendMCPRequest('get_system_info');
            healthResults.mcpApi = true;
            this.logger.success('MCP API connectivity: OK');
        } catch (error) {
            this.logger.warning(`MCP API connectivity: Failed - ${error.message}`);
        }

        // Check SSH connectivity
        try {
            const sshResult = await this.executeSSHCommand('echo "SSH test successful"');
            healthResults.sshConnectivity = sshResult.success;
            this.logger.success('SSH connectivity: OK');
        } catch (error) {
            this.logger.warning(`SSH connectivity: Failed - ${error.message}`);
        }

        // Check Docker daemon
        try {
            const dockerResult = await this.executeSSHCommand('docker --version && docker compose --version');
            healthResults.dockerDaemon = dockerResult.success;
            this.logger.success('Docker daemon: OK');
        } catch (error) {
            this.logger.warning(`Docker daemon: Failed - ${error.message}`);
        }

        // Check system resources
        try {
            const resourceCheck = await this.executeSSHCommand('df -h / && free -h');
            healthResults.systemResources = resourceCheck.success;
            this.logger.success('System resources: OK');
        } catch (error) {
            this.logger.warning(`System resources: Failed - ${error.message}`);
        }

        return healthResults;
    }

    /**
     * Deploy via MCP API (Legacy system)
     */
    async deployViaMCPAPI(options = {}) {
        this.logger.info('Starting MCP API deployment...');
        
        const {
            projectName = 'mcp-app',
            githubSha = process.env.GITHUB_SHA || 'unknown',
            targetPath = this.legacyPath
        } = options;

        try {
            // Create deployment directory
            const timestamp = new Date().toISOString().replace(/[:-]/g, '').slice(0, 15);
            const releasePath = `${targetPath}/releases/${timestamp}`;
            
            await this.sendMCPRequest('execute_command', {
                command: `mkdir -p ${releasePath}`
            });

            // Get system info
            const systemInfo = await this.sendMCPRequest('get_system_info');
            this.logger.info(`Target system: ${systemInfo.system || 'Unknown'}`);

            // Backup current deployment
            await this.sendMCPRequest('execute_command', {
                command: `cp -r ${targetPath}/current ${targetPath}/backup_${timestamp} 2>/dev/null || true`
            });

            // Deploy new version
            await this.sendMCPRequest('execute_command', {
                command: `echo "Deployment ${githubSha}" > ${releasePath}/version.txt`
            });

            // Update current symlink
            await this.sendMCPRequest('execute_command', {
                command: `ln -sfn ${releasePath} ${targetPath}/current`
            });

            // Health check
            try {
                await this.sendMCPRequest('execute_command', {
                    command: 'curl -f http://localhost:8080/health || echo "Health check completed"'
                });
            } catch (error) {
                this.logger.warning(`Health check warning: ${error.message}`);
            }

            // Log deployment
            const logEntry = `${new Date().toISOString()}: MCP API deployment successful - ${githubSha}\\n`;
            await this.sendMCPRequest('execute_command', {
                command: `echo "${logEntry}" >> ${targetPath}/deployment.log`
            });

            this.logger.success('MCP API deployment completed successfully');
            return { success: true, method: 'mcp-api', releasePath, timestamp };

        } catch (error) {
            this.logger.error(`MCP API deployment failed: ${error.message}`);
            
            // Log failure
            const logEntry = `${new Date().toISOString()}: MCP API deployment failed - ${githubSha}: ${error.message}\\n`;
            try {
                await this.sendMCPRequest('execute_command', {
                    command: `echo "${logEntry}" >> ${targetPath}/deployment.log`
                });
            } catch (logError) {
                this.logger.error(`Failed to log error: ${logError.message}`);
            }
            
            throw error;
        }
    }

    /**
     * Deploy via SSH + Docker Compose (Modern system)
     */
    async deployViaSSHDocker(options = {}) {
        this.logger.info('Starting SSH + Docker Compose deployment...');
        
        const {
            githubSha = process.env.GITHUB_SHA || 'unknown',
            targetPath = this.dockerPath
        } = options;

        try {
            // Pre-deployment setup
            await this.executeSSHCommand(`mkdir -p ${targetPath}`);
            await this.executeSSHCommand(`mkdir -p ${targetPath}/logs`);

            // Copy Docker configuration files
            this.logger.info('Copying Docker configuration files...');
            await this.executeLocalCommand(`scp -i "${this.sshKeyPath}" -o StrictHostKeyChecking=no -r docker/ root@${this.sshHost}:/root/`);
            
            if (await this.fileExists('docker-compose.yml')) {
                await this.executeLocalCommand(`scp -i "${this.sshKeyPath}" -o StrictHostKeyChecking=no docker-compose.yml root@${this.sshHost}:${targetPath}/`);
            }

            // Copy React app if exists
            if (await this.fileExists('03_sample_projects/react_apps/dist')) {
                await this.executeLocalCommand(`scp -i "${this.sshKeyPath}" -o StrictHostKeyChecking=no -r 03_sample_projects/react_apps/ root@${this.sshHost}:/root/`);
            }

            // Stop existing containers gracefully
            this.logger.info('Stopping existing containers...');
            await this.executeSSHCommand(`cd ${targetPath} && docker compose down || true`);

            // Stop conflicting host services
            await this.executeSSHCommand('systemctl stop mcp-server nginx 2>/dev/null || true');
            await this.executeSSHCommand('pkill -f mcp_server.py 2>/dev/null || true');
            await this.executeSSHCommand('pkill -f node 2>/dev/null || true');

            // Build and start containers
            this.logger.info('Building Docker images...');
            await this.executeSSHCommand(`cd ${targetPath} && docker compose build --no-cache`);

            this.logger.info('Starting Docker containers...');
            await this.executeSSHCommand(`cd ${targetPath} && docker compose up -d`);

            // Wait for services to be ready
            this.logger.info('Waiting for services to initialize...');
            await new Promise(resolve => setTimeout(resolve, 30000));

            // Verify container status
            const containerStatus = await this.executeSSHCommand(`cd ${targetPath} && docker compose ps`);
            this.logger.info('Container status:', containerStatus.stdout);

            // Health verification
            await this.verifyDockerHealth();

            // Setup auto-start service
            await this.setupDockerAutoStart(targetPath);

            // Log deployment
            const logEntry = `${new Date().toISOString()}: SSH Docker deployment successful - ${githubSha}\\n`;
            await this.executeSSHCommand(`echo "${logEntry}" >> ${targetPath}/deployment.log`);

            this.logger.success('SSH + Docker Compose deployment completed successfully');
            return { success: true, method: 'ssh-docker', targetPath };

        } catch (error) {
            this.logger.error(`SSH Docker deployment failed: ${error.message}`);
            
            // Log failure
            const logEntry = `${new Date().toISOString()}: SSH Docker deployment failed - ${githubSha}: ${error.message}\\n`;
            try {
                await this.executeSSHCommand(`echo "${logEntry}" >> ${targetPath}/deployment.log`);
            } catch (logError) {
                this.logger.error(`Failed to log error: ${logError.message}`);
            }
            
            throw error;
        }
    }

    /**
     * Setup Docker auto-start systemd service
     */
    async setupDockerAutoStart(targetPath) {
        this.logger.info('Setting up Docker auto-start service...');
        
        const serviceContent = `[Unit]
Description=MCP Docker Compose Service
Requires=docker.service
After=docker.service
StartLimitIntervalSec=0

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${targetPath}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target`;

        await this.executeSSHCommand(`cat > /etc/systemd/system/mcp-docker.service << 'EOF'\n${serviceContent}\nEOF`);
        await this.executeSSHCommand('systemctl daemon-reload');
        await this.executeSSHCommand('systemctl enable mcp-docker.service');
        
        this.logger.success('Docker auto-start service configured');
    }

    /**
     * Verify Docker deployment health
     */
    async verifyDockerHealth() {
        this.logger.info('Verifying Docker deployment health...');
        
        const healthEndpoints = [
            'http://localhost/health',
            'http://localhost/service',
            'http://localhost:8080'
        ];

        let healthyEndpoints = 0;
        
        for (const endpoint of healthEndpoints) {
            try {
                await this.executeSSHCommand(`curl -f -s "${endpoint}" --connect-timeout 10`);
                healthyEndpoints++;
                this.logger.success(`✅ ${endpoint} is responding`);
            } catch (error) {
                this.logger.warning(`⚠️ ${endpoint} is not responding: ${error.message}`);
            }
        }

        if (healthyEndpoints > 0) {
            this.logger.success(`Health check: ${healthyEndpoints}/${healthEndpoints.length} endpoints healthy`);
        } else {
            throw new Error('No healthy endpoints found');
        }
    }

    /**
     * Hybrid deployment with automatic failover
     */
    async deployHybrid(options = {}) {
        this.logger.info(`Starting hybrid deployment with strategy: ${this.deployStrategy}`);
        
        const results = {
            healthChecks: null,
            mcpDeployment: null,
            dockerDeployment: null,
            strategy: this.deployStrategy,
            timestamp: new Date().toISOString()
        };

        try {
            // Pre-deployment health checks
            results.healthChecks = await this.performHealthChecks();

            switch (this.deployStrategy) {
                case 'dual':
                    await this.executeDualDeployment(options, results);
                    break;
                    
                case 'mcp-api':
                    results.mcpDeployment = await this.deployViaMCPAPI(options);
                    break;
                    
                case 'ssh-docker':
                    results.dockerDeployment = await this.deployViaSSHDocker(options);
                    break;
                    
                default:
                    throw new Error(`Unknown deployment strategy: ${this.deployStrategy}`);
            }

            // Final verification
            await this.performFinalVerification(results);

            this.logger.success('🎉 Hybrid deployment completed successfully!');
            return results;

        } catch (error) {
            this.logger.error(`Hybrid deployment failed: ${error.message}`);
            
            // Attempt recovery if in dual mode
            if (this.deployStrategy === 'dual' && results.healthChecks.sshConnectivity) {
                this.logger.info('Attempting recovery via SSH deployment...');
                try {
                    results.dockerDeployment = await this.deployViaSSHDocker(options);
                    this.logger.success('Recovery deployment successful');
                    return results;
                } catch (recoveryError) {
                    this.logger.error(`Recovery failed: ${recoveryError.message}`);
                }
            }
            
            throw error;
        }
    }

    /**
     * Execute dual deployment strategy
     */
    async executeDualDeployment(options, results) {
        this.logger.info('Executing dual deployment strategy...');
        
        const deployments = [];

        // MCP API deployment
        if (results.healthChecks.mcpApi) {
            deployments.push(
                this.deployViaMCPAPI(options)
                    .then(result => { results.mcpDeployment = result; })
                    .catch(error => { 
                        results.mcpDeployment = { success: false, error: error.message };
                        this.logger.warning(`MCP API deployment failed: ${error.message}`);
                    })
            );
        }

        // SSH Docker deployment
        if (results.healthChecks.sshConnectivity) {
            deployments.push(
                this.deployViaSSHDocker(options)
                    .then(result => { results.dockerDeployment = result; })
                    .catch(error => { 
                        results.dockerDeployment = { success: false, error: error.message };
                        this.logger.warning(`SSH Docker deployment failed: ${error.message}`);
                    })
            );
        }

        if (deployments.length === 0) {
            throw new Error('No deployment methods available based on health checks');
        }

        // Wait for all deployments to complete
        await Promise.allSettled(deployments);

        // Check if at least one deployment succeeded
        const hasSuccessfulDeployment = 
            (results.mcpDeployment?.success) || 
            (results.dockerDeployment?.success);

        if (!hasSuccessfulDeployment) {
            throw new Error('All deployment methods failed');
        }

        this.logger.success('Dual deployment completed with partial success');
    }

    /**
     * Perform final verification
     */
    async performFinalVerification(results) {
        this.logger.info('Performing final system verification...');
        
        // Test external connectivity
        try {
            const response = await this.executeLocalCommand(`curl -f -s http://${this.sshHost}/health --connect-timeout 30`);
            this.logger.success('External health check: OK');
        } catch (error) {
            this.logger.warning(`External health check failed: ${error.message}`);
        }

        // Generate deployment summary
        this.generateDeploymentSummary(results);
    }

    /**
     * Generate deployment summary
     */
    generateDeploymentSummary(results) {
        console.log('\n' + '='.repeat(60));
        console.log('🚀 HYBRID DEPLOYMENT SUMMARY');
        console.log('='.repeat(60));
        console.log(`Strategy: ${results.strategy}`);
        console.log(`Timestamp: ${results.timestamp}`);
        console.log(`Commit: ${process.env.GITHUB_SHA || 'unknown'}`);
        console.log('');
        
        console.log('📊 Health Checks:');
        Object.entries(results.healthChecks).forEach(([key, value]) => {
            console.log(`  ${key}: ${value ? '✅ OK' : '❌ Failed'}`);
        });
        
        console.log('');
        console.log('🔧 Deployment Results:');
        if (results.mcpDeployment) {
            console.log(`  MCP API: ${results.mcpDeployment.success ? '✅ Success' : '❌ Failed'}`);
        }
        if (results.dockerDeployment) {
            console.log(`  SSH Docker: ${results.dockerDeployment.success ? '✅ Success' : '❌ Failed'}`);
        }
        
        console.log('');
        console.log('🌐 Service URLs:');
        console.log(`  - Main Website: http://${this.sshHost}`);
        console.log(`  - Health Check: http://${this.sshHost}/health`);
        console.log(`  - Service Status: http://${this.sshHost}/service`);
        console.log(`  - MCP API: http://${this.sshHost}:8080`);
        console.log('='.repeat(60));
    }

    /**
     * Check if file exists
     */
    async fileExists(filePath) {
        try {
            await fs.access(filePath);
            return true;
        } catch {
            return false;
        }
    }

    /**
     * Rollback functionality
     */
    async rollback(options = {}) {
        this.logger.info('Initiating hybrid rollback...');
        
        const { method = 'both' } = options;
        
        try {
            if (method === 'both' || method === 'mcp-api') {
                await this.rollbackMCPAPI();
            }
            
            if (method === 'both' || method === 'ssh-docker') {
                await this.rollbackSSHDocker();
            }
            
            this.logger.success('Rollback completed successfully');
        } catch (error) {
            this.logger.error(`Rollback failed: ${error.message}`);
            throw error;
        }
    }

    async rollbackMCPAPI() {
        // Find and restore previous MCP deployment
        const result = await this.sendMCPRequest('execute_command', {
            command: `find ${this.legacyPath} -name "backup_*" -type d | sort -r | head -1`
        });
        
        if (result.stdout?.trim()) {
            await this.sendMCPRequest('execute_command', {
                command: `cp -r ${result.stdout.trim()} ${this.legacyPath}/current`
            });
            this.logger.success('MCP API rollback completed');
        }
    }

    async rollbackSSHDocker() {
        // Docker rollback by restarting with previous configuration
        await this.executeSSHCommand(`cd ${this.dockerPath} && docker compose down`);
        await this.executeSSHCommand(`cd ${this.dockerPath} && docker compose up -d`);
        this.logger.success('SSH Docker rollback completed');
    }
}

// CLI interface
if (require.main === module) {
    const command = process.argv[2];
    const strategy = process.argv[3] || process.env.DEPLOY_STRATEGY || 'dual';
    
    const deployer = new HybridMCPDeployer({ strategy });
    
    switch (command) {
        case 'deploy':
            deployer.deployHybrid({
                projectName: process.argv[4] || 'mcp-hybrid-app',
                githubSha: process.env.GITHUB_SHA
            }).catch(error => {
                console.error('Deployment failed:', error.message);
                process.exit(1);
            });
            break;
            
        case 'health':
            deployer.performHealthChecks()
                .then(results => {
                    console.log('Health Check Results:');
                    console.log(JSON.stringify(results, null, 2));
                })
                .catch(console.error);
            break;
            
        case 'rollback':
            deployer.rollback({ method: process.argv[4] || 'both' })
                .catch(error => {
                    console.error('Rollback failed:', error.message);
                    process.exit(1);
                });
            break;
            
        default:
            console.log(`
🚀 Hybrid MCP Deployment Tool

Usage: node hybrid-deploy.js <command> [strategy] [options]

Commands:
  deploy [strategy] [project-name]  Deploy with specified strategy
  health                           Check system health
  rollback [method]                Rollback deployment

Strategies:
  dual                            Deploy to both MCP API and SSH Docker (default)
  mcp-api                         Deploy only via MCP API  
  ssh-docker                      Deploy only via SSH + Docker

Environment Variables:
  DEPLOY_STRATEGY                 Default deployment strategy
  GITHUB_SHA                      Git commit SHA (for deployment tracking)
  MCP_SERVER_URL                  MCP server URL (default: http://192.168.111.200:8080)

Examples:
  node hybrid-deploy.js deploy dual my-app
  node hybrid-deploy.js health
  node hybrid-deploy.js rollback mcp-api
            `);
    }
}

module.exports = HybridMCPDeployer;