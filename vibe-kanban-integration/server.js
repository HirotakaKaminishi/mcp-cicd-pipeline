const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const SecurityMiddleware = require('./security/auth-middleware');
const GitHubIntegration = require('./github/integration');
require('dotenv').config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Initialize security middleware
const security = new SecurityMiddleware({
  enterpriseMode: process.env.ENTERPRISE_MODE === 'true',
  enableRateLimit: true,
  enableCSRF: true
});

// Initialize GitHub integration
const github = new GitHubIntegration({
  token: process.env.GITHUB_TOKEN,
  webhookSecret: process.env.GITHUB_WEBHOOK_SECRET,
  owner: 'HirotakaKaminishi',
  repo: 'mcp-cicd-pipeline'
});

// Apply security middleware
app.use(security.helmetConfig());
app.use(security.securityLogger());
app.use(security.enterpriseSecurityMode());

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000', 'http://192.168.111.200'],
  credentials: true
}));

// Logging
app.use(morgan('combined'));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Environment variables validation
const requiredEnvVars = [
  'MCP_SERVER_URL',
  'GITHUB_TOKEN'
];

const missingEnvVars = requiredEnvVars.filter(envVar => !process.env[envVar]);
if (missingEnvVars.length > 0) {
  console.warn(`⚠️  Missing environment variables: ${missingEnvVars.join(', ')}`);
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    services: {
      mcpServer: process.env.MCP_SERVER_URL || 'not configured',
      github: process.env.GITHUB_TOKEN ? 'configured' : 'not configured'
    }
  });
});

// MCP Integration endpoint
app.get('/api/mcp/status', async (req, res) => {
  try {
    const axios = require('axios');
    const mcpResponse = await axios.get(`${process.env.MCP_SERVER_URL}/health`, {
      timeout: 5000
    });
    
    res.status(200).json({
      status: 'connected',
      mcpServer: mcpResponse.data,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('MCP connection error:', error.message);
    res.status(503).json({
      status: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Rate limiting for API endpoints
app.use('/api', security.createRateLimiter(15 * 60 * 1000, 100)); // 100 requests per 15 minutes

// Agent concurrency limiting
app.use('/api/kanban', security.createAgentLimiter());

// Critical path protection
app.use('/api/kanban', security.protectCriticalPaths());

// Vibe-Kanban API endpoints with security
app.use('/api/kanban', (req, res, next) => {
  // Apply authentication for sensitive operations
  const sensitiveOperations = ['POST', 'PUT', 'DELETE', 'PATCH'];
  
  if (sensitiveOperations.includes(req.method)) {
    // For development, skip token validation but log the operation
    console.info('Sensitive operation detected:', {
      method: req.method,
      path: req.path,
      agent: req.headers['x-agent-type'],
      timestamp: new Date().toISOString()
    });
  }
  
  next();
});

// GitHub webhook endpoint
app.post('/api/github/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  try {
    const signature = req.headers['x-hub-signature-256'];
    const event = req.headers['x-github-event'];
    const payload = req.body.toString();

    console.log(`Received GitHub webhook: ${event}`);

    const result = await github.handleWebhook(event, payload, signature);
    
    res.status(200).json({
      success: true,
      message: result.message || 'Webhook processed successfully',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('GitHub webhook error:', error);
    res.status(400).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// GitHub integration API endpoints
app.get('/api/github/repository', async (req, res) => {
  try {
    const result = await github.getRepositoryInfo();
    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.get('/api/github/pull-requests', async (req, res) => {
  try {
    const result = await github.listOpenPullRequests();
    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.post('/api/github/create-branch', async (req, res) => {
  try {
    const { taskId, baseBranch } = req.body;
    
    if (!taskId) {
      return res.status(400).json({
        success: false,
        error: 'taskId is required'
      });
    }

    const result = await github.createBranch(taskId, baseBranch);
    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.post('/api/github/create-pr', async (req, res) => {
  try {
    const taskData = req.body;
    
    if (!taskData.id || !taskData.title) {
      return res.status(400).json({
        success: false,
        error: 'Task id and title are required'
      });
    }

    const result = await github.createPullRequest(taskData);
    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Static files (if needed for custom UI)
app.use('/static', express.static(path.join(__dirname, 'public')));

// Default route
app.get('/', (req, res) => {
  res.json({
    message: 'Vibe-Kanban MCP Integration Server',
    version: process.env.npm_package_version || '1.0.0',
    endpoints: {
      health: '/health',
      mcpStatus: '/api/mcp/status',
      kanbanApi: '/api/kanban/*'
    },
    documentation: 'https://github.com/BloopAI/vibe-kanban'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err.stack);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 Vibe-Kanban Integration Server started');
  console.log(`📡 Server running on http://0.0.0.0:${PORT}`);
  console.log(`🔧 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔌 MCP Server: ${process.env.MCP_SERVER_URL || 'not configured'}`);
  console.log(`🔐 GitHub Integration: ${process.env.GITHUB_TOKEN ? 'enabled' : 'disabled'}`);
  console.log('📋 Health check available at /health');
});

module.exports = app;