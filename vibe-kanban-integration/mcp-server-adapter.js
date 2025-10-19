#!/usr/bin/env node

/**
 * MCP Server Adapter for Vibe-Kanban Integration
 * This adapter bridges Claude Code with Vibe-Kanban through the MCP protocol
 */

// MCP Server adapter without external SDK - using HTTP-based communication
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');

class VibeKanbanMCPAdapter {
  constructor() {
    this.mcpServerUrl = process.env.MCP_SERVER_URL || 'http://mcp-server:8080';
    this.vibeKanbanUrl = process.env.VIBE_KANBAN_URL || 'http://vibe-kanban:3000';
    this.logLevel = process.env.LOG_LEVEL || 'info';
    this.tools = new Map();
    
    this.setupTools();
    this.setupResources();
    this.setupPrompts();
  }

  log(level, message, data = null) {
    if (this.shouldLog(level)) {
      const timestamp = new Date().toISOString();
      const logEntry = {
        timestamp,
        level: level.toUpperCase(),
        message,
        ...(data && { data })
      };
      console.log(JSON.stringify(logEntry));
    }
  }

  shouldLog(level) {
    const levels = { error: 0, warn: 1, info: 2, debug: 3 };
    return levels[level] <= levels[this.logLevel];
  }

  setupTools() {
    // Create Vibe-Kanban task
    this.tools.set('vibe_kanban_create_task', {
      name: 'vibe_kanban_create_task',
      description: 'Create a new task in Vibe-Kanban board with AI agent assignment',
      inputSchema: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Task title' },
          description: { type: 'string', description: 'Detailed task description' },
          assignedAgent: { 
            type: 'string', 
            enum: ['claude-code', 'gemini-cli', 'amp', 'auto'],
            description: 'AI agent to assign the task to'
          },
          priority: {
            type: 'string',
            enum: ['low', 'medium', 'high', 'critical'],
            default: 'medium'
          },
          category: {
            type: 'string',
            enum: ['refactoring', 'testing', 'documentation', 'bug-fixes', 'feature-development']
          },
          repository: { type: 'string', description: 'Target repository' }
        },
        required: ['title', 'description', 'category']
      },
      handler: async (params) => {
      try {
        this.log('info', 'Creating Vibe-Kanban task', params);
        
        const taskData = {
          ...params,
          status: 'todo',
          createdBy: 'claude-code',
          timestamp: new Date().toISOString(),
          source: 'mcp-adapter'
        };

        const response = await axios.post(`${this.vibeKanbanUrl}/api/kanban/tasks`, taskData, {
          timeout: 10000,
          headers: { 'Content-Type': 'application/json' }
        });

        this.log('info', 'Task created successfully', { taskId: response.data.id });
        
        return {
          success: true,
          taskId: response.data.id,
          message: `Task "${params.title}" created and assigned to ${params.assignedAgent || 'auto'}`
        };
      } catch (error) {
        this.log('error', 'Failed to create task', { error: error.message });
        throw new Error(`Failed to create task: ${error.message}`);
      }
    });

    // Update task status
    this.server.addTool({
      name: 'vibe_kanban_update_task',
      description: 'Update task status and progress',
      inputSchema: {
        type: 'object',
        properties: {
          taskId: { type: 'string' },
          status: {
            type: 'string',
            enum: ['todo', 'in_progress', 'review', 'done', 'blocked']
          },
          progress: { type: 'number', minimum: 0, maximum: 100 },
          notes: { type: 'string', description: 'Progress notes' }
        },
        required: ['taskId']
      }
    }, async (params) => {
      try {
        this.log('info', 'Updating task', params);
        
        const updateData = {
          ...params,
          lastUpdated: new Date().toISOString(),
          updatedBy: 'claude-code'
        };

        await axios.patch(`${this.vibeKanbanUrl}/api/kanban/tasks/${params.taskId}`, updateData, {
          timeout: 5000
        });

        return {
          success: true,
          message: `Task ${params.taskId} updated successfully`
        };
      } catch (error) {
        this.log('error', 'Failed to update task', { taskId: params.taskId, error: error.message });
        throw new Error(`Failed to update task: ${error.message}`);
      }
    });

    // List tasks
    this.server.addTool({
      name: 'vibe_kanban_list_tasks',
      description: 'List tasks with filtering options',
      inputSchema: {
        type: 'object',
        properties: {
          status: { type: 'string', enum: ['todo', 'in_progress', 'review', 'done', 'blocked', 'all'], default: 'all' },
          assignedAgent: { type: 'string' },
          category: { type: 'string' }
        }
      }
    }, async (params) => {
      try {
        this.log('info', 'Listing tasks', params);
        
        const queryParams = new URLSearchParams(params);
        const response = await axios.get(`${this.vibeKanbanUrl}/api/kanban/tasks?${queryParams}`, {
          timeout: 5000
        });

        return {
          success: true,
          tasks: response.data.tasks || [],
          total: response.data.total || 0
        };
      } catch (error) {
        this.log('error', 'Failed to list tasks', { error: error.message });
        throw new Error(`Failed to list tasks: ${error.message}`);
      }
    });

    // Get agent status
    this.server.addTool({
      name: 'vibe_kanban_agent_status',
      description: 'Get status of all AI agents and their current tasks',
      inputSchema: {
        type: 'object',
        properties: {}
      }
    }, async (params) => {
      try {
        this.log('info', 'Getting agent status');
        
        const response = await axios.get(`${this.vibeKanbanUrl}/api/kanban/agents/status`, {
          timeout: 5000
        });

        return {
          success: true,
          agents: response.data.agents || {},
          timestamp: new Date().toISOString()
        };
      } catch (error) {
        this.log('error', 'Failed to get agent status', { error: error.message });
        throw new Error(`Failed to get agent status: ${error.message}`);
      }
    });
  }

  setupResources() {
    // Vibe-Kanban configuration resource
    this.server.addResource({
      uri: 'vibe-kanban://config',
      name: 'Vibe-Kanban Configuration',
      description: 'Current Vibe-Kanban configuration and settings',
      mimeType: 'application/json'
    }, async () => {
      try {
        const configPath = path.join(__dirname, 'claude-code-config.json');
        const config = await fs.readFile(configPath, 'utf8');
        return JSON.parse(config);
      } catch (error) {
        this.log('error', 'Failed to read config', { error: error.message });
        throw new Error('Configuration not available');
      }
    });

    // Task statistics resource
    this.server.addResource({
      uri: 'vibe-kanban://stats',
      name: 'Task Statistics',
      description: 'Current task statistics and metrics',
      mimeType: 'application/json'
    }, async () => {
      try {
        const response = await axios.get(`${this.vibeKanbanUrl}/api/kanban/stats`, {
          timeout: 5000
        });
        return response.data;
      } catch (error) {
        this.log('error', 'Failed to get statistics', { error: error.message });
        throw new Error('Statistics not available');
      }
    });
  }

  setupPrompts() {
    // Task creation prompt
    this.server.addPrompt({
      name: 'create_development_task',
      description: 'Create a well-structured development task for AI agents',
      arguments: [
        { name: 'feature', description: 'Feature or component to work on' },
        { name: 'priority', description: 'Task priority level' }
      ]
    }, async (args) => {
      return {
        messages: [
          {
            role: 'user',
            content: `Create a development task for "${args.feature}" with priority "${args.priority}". 
            
            Please ensure the task includes:
            1. Clear acceptance criteria
            2. Proper category assignment
            3. Estimated complexity
            4. Dependencies (if any)
            5. Testing requirements
            
            Use the vibe_kanban_create_task tool to create the task.`
          }
        ]
      };
    });
  }

  async start() {
    try {
      await this.server.connect();
      this.log('info', 'Vibe-Kanban MCP Adapter started', {
        mcpServerUrl: this.mcpServerUrl,
        vibeKanbanUrl: this.vibeKanbanUrl
      });
    } catch (error) {
      this.log('error', 'Failed to start MCP server', { error: error.message });
      process.exit(1);
    }
  }

  async healthCheck() {
    try {
      // Check Vibe-Kanban health
      await axios.get(`${this.vibeKanbanUrl}/health`, { timeout: 3000 });
      
      // Check MCP server health
      await axios.get(`${this.mcpServerUrl}/health`, { timeout: 3000 });
      
      return { status: 'healthy' };
    } catch (error) {
      this.log('warn', 'Health check failed', { error: error.message });
      return { status: 'unhealthy', error: error.message };
    }
  }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully');
  process.exit(0);
});

// Start the adapter
const adapter = new VibeKanbanMCPAdapter();
adapter.start().catch(error => {
  console.error('Failed to start adapter:', error);
  process.exit(1);
});

module.exports = VibeKanbanMCPAdapter;