#!/bin/sh
set -e

echo "=========================================="
echo "CI/CD Test Deployment - $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo "Starting Vibe-Kanban Mock Backend on port 3002 (ApiResponse format with CRUD)..."

node -e "
const http = require('http');
const url = require('url');
const PORT = 3002;

const createApiResponse = (data) => ({
  success: true,
  data: data
});

// Mock data with in-memory storage
let mockProjects = [
  {
    id: 'demo-project',
    name: 'Demo Project',
    description: 'Sample project for demonstration',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    status: 'active',
    language: 'typescript',
    script_language: 'typescript',
    path: '/app/demo-project',
    directory: '/app/demo-project',
    repository_url: 'https://github.com/demo/demo-project',
    ai_agent_type: 'claude-code',
    settings: {
      auto_commit: false,
      enable_ai: true,
      test_on_save: false
    }
  }
];

let mockTemplates = [
  {
    id: 'template-1',
    name: 'Task Template',
    description: 'Default task template',
    project_id: 'demo-project',
    content: {title: 'New Task', priority: 'medium'},
    created_at: new Date().toISOString()
  },
  {
    id: 'global-template-1',
    name: 'Global Template',
    description: 'Global task template',
    global: true,
    content: {title: 'Global Task', priority: 'high'},
    created_at: new Date().toISOString()
  }
];

let mockTasks = [
  {
    id: 'task-1',
    project_id: 'demo-project',
    title: 'Setup Project',
    description: 'Initialize project structure',
    status: 'in_progress',
    priority: 'high',
    created_at: new Date().toISOString()
  },
  {
    id: 'task-2',
    project_id: 'demo-project',
    title: 'Add Features',
    description: 'Implement core features',
    status: 'todo',
    priority: 'medium',
    created_at: new Date().toISOString()
  }
];

// Helper to read request body
const getRequestBody = (req) => {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
};

const server = http.createServer(async (req, res) => {
  const timestamp = new Date().toISOString();
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const query = parsedUrl.query;
  const method = req.method;

  console.log(\`[\${timestamp}] \${method} \${req.url}\`);

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');

  if (method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Server-Sent Events (SSE) endpoint for raw logs
  if (method === 'GET' && pathname.match(/^\/api\/execution-processes\/[\w-]+\/raw-logs$/)) {
    const processId = pathname.split('/')[3];
    console.log(\`[\${timestamp}] -> SSE connection established for process raw-logs: \${processId}\`);

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    // Send initial json_patch event
    const initialPatch = [
      {
        op: 'add',
        path: '/entries/0',
        value: {
          type: 'STDOUT',
          content: 'Starting execution process...\\n'
        }
      }
    ];
    res.write('event: json_patch\\n');
    res.write('data: ' + JSON.stringify(initialPatch) + '\\n\\n');

    // Send periodic log updates
    let logCount = 1;
    const intervalId = setInterval(() => {
      const logMessages = [
        '[INFO] Initializing AI agent',
        '[INFO] Loading codebase context',
        '[DEBUG] Analyzing file structure',
        '[INFO] Generating code changes',
        '[SUCCESS] Changes applied successfully'
      ];

      if (logCount < logMessages.length) {
        const patch = [
          {
            op: 'add',
            path: \`/entries/\${logCount}\`,
            value: {
              type: 'STDOUT',
              content: logMessages[logCount] + '\\n'
            }
          }
        ];
        res.write('event: json_patch\\n');
        res.write('data: ' + JSON.stringify(patch) + '\\n\\n');
        logCount++;
      } else {
        res.write('event: finished\\n');
        res.write('data: {}\\n\\n');
        clearInterval(intervalId);
        res.end();
      }
    }, 1000);

    // Cleanup on connection close
    req.on('close', () => {
      clearInterval(intervalId);
      console.log(\`[\${new Date().toISOString()}] -> SSE connection closed for raw-logs: \${processId}\`);
    });

    return;
  }

  // Server-Sent Events (SSE) endpoint for normalized logs
  if (method === 'GET' && pathname.match(/^\/api\/execution-processes\/[\w-]+\/normalized-logs$/)) {
    const processId = pathname.split('/')[3];
    console.log(\`[\${timestamp}] -> SSE connection established for process normalized-logs: \${processId}\`);

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    // Send initial json_patch event with normalized entries
    const initialPatch = [
      {
        op: 'add',
        path: '/entries/0',
        value: {
          type: 'NORMALIZED_ENTRY',
          content: {
            timestamp: new Date().toISOString(),
            entry_type: {type: 'system_message'},
            content: 'Process started'
          }
        }
      }
    ];
    res.write('event: json_patch\\n');
    res.write('data: ' + JSON.stringify(initialPatch) + '\\n\\n');

    // Send periodic normalized entry updates
    let entryCount = 1;
    const intervalId = setInterval(() => {
      const entries = [
        {type: {type: 'user_message'}, content: 'Implement the requested feature'},
        {type: {type: 'assistant_message'}, content: 'I will help you implement this feature. Let me analyze the codebase first.'},
        {type: {type: 'tool_use', tool_name: 'read_file', action_type: {action: 'file_read', path: '/src/main.ts'}}, content: 'Reading file: /src/main.ts'},
        {type: {type: 'assistant_message'}, content: 'I have analyzed the code. Now I will make the necessary changes.'},
        {type: {type: 'tool_use', tool_name: 'edit_file', action_type: {action: 'file_edit', path: '/src/main.ts', changes: []}}, content: 'Editing file: /src/main.ts'}
      ];

      if (entryCount < entries.length) {
        const patch = [
          {
            op: 'add',
            path: \`/entries/\${entryCount}\`,
            value: {
              type: 'NORMALIZED_ENTRY',
              content: {
                timestamp: new Date().toISOString(),
                entry_type: entries[entryCount].type,
                content: entries[entryCount].content
              }
            }
          }
        ];
        res.write('event: json_patch\\n');
        res.write('data: ' + JSON.stringify(patch) + '\\n\\n');
        entryCount++;
      } else {
        res.write('event: finished\\n');
        res.write('data: {}\\n\\n');
        clearInterval(intervalId);
        res.end();
      }
    }, 2000);

    // Cleanup on connection close
    req.on('close', () => {
      clearInterval(intervalId);
      console.log(\`[\${new Date().toISOString()}] -> SSE connection closed for normalized-logs: \${processId}\`);
    });

    return;
  }

  // Server-Sent Events (SSE) endpoint for diff streaming
  if (method === 'GET' && pathname.match(/^\/api\/task-attempts\/[\w-]+\/diff$/)) {
    const attemptId = pathname.split('/')[3];
    console.log(\`[\${timestamp}] -> SSE connection established for task attempt diff: \${attemptId}\`);

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    // Send initial json_patch events to build entries object
    const files = [
      {
        path: 'src/components/example.tsx',
        diff: '--- a/src/components/example.tsx\\n+++ b/src/components/example.tsx\\n@@ -10,7 +10,7 @@\\n   return (\\n     <div>\\n-      <h1>Old Title</h1>\\n+      <h1>New Title</h1>\\n       <p>Content here</p>\\n     </div>\\n   );',
        additions: 1,
        deletions: 1
      },
      {
        path: 'src/lib/utils.ts',
        diff: '--- a/src/lib/utils.ts\\n+++ b/src/lib/utils.ts\\n@@ -5,3 +5,7 @@\\n export function formatDate(date: Date): string {\\n   return date.toISOString();\\n }\\n+\\n+export function capitalize(str: string): string {\\n+  return str.charAt(0).toUpperCase() + str.slice(1);\\n+}',
        additions: 4,
        deletions: 0
      },
      {
        path: 'src/types/index.ts',
        diff: '--- a/src/types/index.ts\\n+++ b/src/types/index.ts\\n@@ -1,3 +1,5 @@\\n+export type Status = \\'pending\\' | \\'completed\\' | \\'failed\\';\\n+\\n export interface Task {\\n   id: string;\\n   title: string;',
        additions: 2,
        deletions: 0
      }
    ];

    // Send patches to add each file diff to entries
    files.forEach((file, index) => {
      const patch = [
        {
          op: 'add',
          path: \`/entries/\${file.path}\`,
          value: {
            type: 'DIFF',
            content: {
              file_path: file.path,
              diff: file.diff,
              additions: file.additions,
              deletions: file.deletions,
              status: 'modified'
            }
          }
        }
      ];
      res.write('event: json_patch\\n');
      res.write('data: ' + JSON.stringify(patch) + '\\n\\n');
    });

    // Send finished event after a short delay
    setTimeout(() => {
      res.write('event: finished\\n');
      res.write('data: {}\\n\\n');
      res.end();
    }, 500);

    // Cleanup on connection close
    req.on('close', () => {
      console.log(\`[\${new Date().toISOString()}] -> SSE connection closed for diff: \${attemptId}\`);
    });

    return;
  }

  let responseData = null;
  let statusCode = 200;

  try {
    // GET and HEAD endpoints
    if (method === 'GET' || method === 'HEAD') {
      if (pathname === '/api/info') {
        // Return full UserSystemInfo for config-provider
        responseData = createApiResponse({
          config: {
            config_version: '1.0.0',
            theme: 'SYSTEM',
            profile: 'default',
            disclaimer_acknowledged: true,
            onboarding_acknowledged: true,
            github_login_acknowledged: true,
            telemetry_acknowledged: true,
            notifications: {
              sound_enabled: true,
              push_enabled: false,
              sound_file: 'ABSTRACT_SOUND1'
            },
            editor: {
              editor_type: 'VS_CODE',
              custom_command: null
            },
            github: {
              pat: null,
              oauth_token: null,
              username: null,
              primary_email: null,
              default_pr_base: 'main'
            },
            analytics_enabled: false,
            workspace_dir: '/app/workspace'
          },
          environment: {
            mode: 'local',
            version: '0.0.68',
            platform: 'linux',
            node_version: 'v20.19.4'
          },
          profiles: [
            {
              label: 'default',
              variant_label: 'default',
              settings: {
                max_tokens: 4096,
                temperature: 0.7
              }
            }
          ]
        });
      }
      else if (pathname === '/api/projects' && !query.id) {
        responseData = createApiResponse(mockProjects);
      }
      else if (pathname.match(/^\/api\/projects\/[\w-]+$/)) {
        const projectId = pathname.split('/').pop();
        const project = mockProjects.find(p => p.id === projectId);
        if (project) {
          responseData = createApiResponse(project);
        }
      }
      else if (pathname === '/api/templates') {
        if (query.global === 'true') {
          const globalTemplates = mockTemplates.filter(t => t.global === true);
          responseData = createApiResponse(globalTemplates);
        } else if (query.project_id) {
          const projectTemplates = mockTemplates.filter(t => t.project_id === query.project_id);
          responseData = createApiResponse(projectTemplates);
        } else {
          responseData = createApiResponse(mockTemplates);
        }
      }
      else if (pathname === '/api/tasks') {
        if (query.project_id) {
          const projectTasks = mockTasks.filter(t => t.project_id === query.project_id);
          responseData = createApiResponse(projectTasks);
        } else {
          responseData = createApiResponse(mockTasks);
        }
      }
      else if (pathname === '/api/profiles') {
        // Return profiles file content for editor
        const profilesContent = JSON.stringify([
          {
            label: 'default',
            variant_label: 'default',
            settings: {
              max_tokens: 4096,
              temperature: 0.7,
              model: 'claude-sonnet-4-5'
            }
          },
          {
            label: 'fast',
            variant_label: 'fast',
            settings: {
              max_tokens: 2048,
              temperature: 0.5,
              model: 'claude-sonnet-3-5'
            }
          }
        ], null, 2);
        responseData = createApiResponse({
          content: profilesContent,
          path: '/app/.config/vibe-kanban/profiles.json'
        });
      }
      else if (pathname === '/api/mcp-config') {
        // Return MCP server configuration for the specified profile
        const profile = query.profile || 'default';
        responseData = createApiResponse({
          mcp_config: {
            servers: {
              'filesystem': {
                command: 'npx',
                args: ['-y', '@modelcontextprotocol/server-filesystem', '/tmp'],
                env: {}
              },
              'brave-search': {
                command: 'npx',
                args: ['-y', '@modelcontextprotocol/server-brave-search'],
                env: {
                  BRAVE_API_KEY: 'your-api-key-here'
                }
              }
            },
            servers_path: ['/app/.config/vibe-kanban/mcp-servers.json'],
            template: {
              mcpServers: {
                'example-server': {
                  command: 'npx',
                  args: ['-y', '@modelcontextprotocol/server-example'],
                  env: {}
                }
              }
            },
            vibe_kanban: {
              version: '0.0.68',
              profile: profile
            },
            is_toml_config: false
          },
          config_path: '/app/.config/vibe-kanban/mcp-servers.json'
        });
        console.log(\`[\${timestamp}] -> MCP config loaded for profile: \${profile}\`);
      }
      else if (pathname === '/api/auth/github/check') {
        responseData = createApiResponse({authenticated: false, message: 'Mock server - GitHub auth not configured'});
      }
      else if (pathname.match(/^\/api\/sounds\/[A-Z0-9_]+$/)) {
        const soundFile = pathname.split('/')[3];
        console.log(\`[\${timestamp}] -> Sound preview requested: \${soundFile} (\${method})\`);
        const riffHeader = Buffer.from([
          0x52, 0x49, 0x46, 0x46, 0xE4, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45
        ]);
        const fmtChunk = Buffer.from([
          0x66, 0x6D, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
          0x44, 0xAC, 0x00, 0x00, 0x88, 0x58, 0x01, 0x00, 0x02, 0x00, 0x10, 0x00
        ]);
        const dataHeader = Buffer.from([
          0x64, 0x61, 0x74, 0x61, 0xC8, 0x00, 0x00, 0x00
        ]);
        const audioData = Buffer.alloc(200, 0);
        const silentWav = Buffer.concat([riffHeader, fmtChunk, dataHeader, audioData]);
        res.writeHead(200, {
          'Content-Type': 'audio/wav',
          'Content-Length': silentWav.length,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Cache-Control': 'public, max-age=31536000'
        });
        if (method === 'HEAD') {
          res.end();
        } else {
          res.end(silentWav);
        }
        return;
      }
      else if (pathname === '/api/filesystem/directory') {
        responseData = createApiResponse({path: '/app', directories: ['frontend', 'backend', 'shared'], files: ['package.json', 'README.md']});
      }
      else if (pathname.match(/^\/api\/projects\/[\w-]+\/branches$/)) {
        const projectId = pathname.split('/')[3];
        responseData = createApiResponse([
          {name: 'main', commit: {sha: 'abc123', message: 'Initial commit'}, protected: true},
          {name: 'develop', commit: {sha: 'def456', message: 'Development branch'}, protected: false},
          {name: 'feature/task-1', commit: {sha: 'ghi789', message: 'Work on task-1'}, protected: false}
        ]);
      }
      else if (pathname === '/api/task-attempts') {
        if (query.task_id) {
          responseData = createApiResponse([
            {
              id: 'attempt-1',
              task_id: query.task_id,
              status: 'completed',
              started_at: new Date(Date.now() - 3600000).toISOString(),
              completed_at: new Date(Date.now() - 1800000).toISOString(),
              result: {success: true, message: 'Task completed successfully'}
            },
            {
              id: 'attempt-2',
              task_id: query.task_id,
              status: 'failed',
              started_at: new Date(Date.now() - 7200000).toISOString(),
              completed_at: new Date(Date.now() - 5400000).toISOString(),
              result: {success: false, message: 'Build failed', error: 'Compilation error'}
            }
          ]);
        } else {
          responseData = createApiResponse([]);
        }
      }
      else if (pathname.match(/^\/api\/task-attempts\/[\w-]+\/branch-status$/)) {
        const attemptId = pathname.split('/')[3];
        responseData = createApiResponse({
          attempt_id: attemptId,
          branch_name: 'feature/task-implementation',
          status: 'open',
          pr_url: null,
          commit_sha: 'abc123def456',
          last_updated: new Date().toISOString()
        });
      }
      else if (pathname === '/api/execution-processes') {
        if (query.task_attempt_id) {
          responseData = createApiResponse([
            {
              id: 'process-1',
              task_attempt_id: query.task_attempt_id,
              run_reason: 'setupscript',
              executor_action: {
                typ: {
                  type: 'ScriptRequest',
                  script: 'npm install',
                  language: 'bash',
                  context: 'SetupScript'
                },
                next_action: null
              },
              status: 'completed',
              started_at: new Date(Date.now() - 3000000).toISOString(),
              completed_at: new Date(Date.now() - 2900000).toISOString(),
              exit_code: 0,
              created_at: new Date(Date.now() - 3000000).toISOString(),
              updated_at: new Date(Date.now() - 2900000).toISOString()
            },
            {
              id: 'process-2',
              task_attempt_id: query.task_attempt_id,
              run_reason: 'codingagent',
              executor_action: {
                typ: {
                  type: 'CodingAgentInitialRequest',
                  profile_variant_label: 'default',
                  prompt: 'Implement the requested feature',
                  files_to_edit: []
                },
                next_action: null
              },
              status: 'running',
              started_at: new Date(Date.now() - 120000).toISOString(),
              completed_at: null,
              exit_code: null,
              created_at: new Date(Date.now() - 120000).toISOString(),
              updated_at: new Date(Date.now() - 60000).toISOString()
            }
          ]);
        } else {
          responseData = createApiResponse([]);
        }
      }
      else if (pathname.match(/^\/api\/execution-processes\/[\w-]+$/) && !pathname.includes('/raw-logs')) {
        const processId = pathname.split('/').pop();
        const mockProcess = processId === 'process-1' ? {
          id: 'process-1',
          task_attempt_id: 'attempt-1',
          run_reason: 'setupscript',
          executor_action: {
            typ: {
              type: 'ScriptRequest',
              script: 'npm install',
              language: 'bash',
              context: 'SetupScript'
            },
            next_action: null
          },
          status: 'completed',
          started_at: new Date(Date.now() - 3000000).toISOString(),
          completed_at: new Date(Date.now() - 2900000).toISOString(),
          exit_code: 0,
          created_at: new Date(Date.now() - 3000000).toISOString(),
          updated_at: new Date(Date.now() - 2900000).toISOString()
        } : {
          id: 'process-2',
          task_attempt_id: 'attempt-1',
          run_reason: 'codingagent',
          executor_action: {
            typ: {
              type: 'CodingAgentInitialRequest',
              profile_variant_label: 'default',
              prompt: 'Implement the requested feature',
              files_to_edit: []
            },
            next_action: null
          },
          status: 'running',
          started_at: new Date(Date.now() - 120000).toISOString(),
          completed_at: null,
          exit_code: null,
          created_at: new Date(Date.now() - 120000).toISOString(),
          updated_at: new Date(Date.now() - 60000).toISOString()
        };
        responseData = createApiResponse(mockProcess);
      }
      // SSE endpoint for diff streaming (removed - now handled above with SSE endpoints)
      // diff endpoint should use SSE, not JSON response
      else if (pathname.match(/^\/api\/images\/task\/[\w-]+$/)) {
        const taskId = pathname.split('/').pop();
        responseData = createApiResponse([]);
        console.log(\`[\${timestamp}] -> Task images requested for: \${taskId} (returning empty array)\`);
      }
    }
    // PUT endpoints
    else if (method === 'PUT') {
      const body = await getRequestBody(req);

      if (pathname === '/api/config') {
        // Save config
        console.log(\`[\${timestamp}] -> Config saved\`, body);
        responseData = createApiResponse(body);
      }
      else if (pathname === '/api/profiles') {
        // Save profiles file
        // body is the raw file content string
        const bodyText = typeof body === 'string' ? body : JSON.stringify(body);
        console.log(\`[\${timestamp}] -> Profiles saved, length: \${bodyText.length}\`);
        responseData = createApiResponse('Profiles saved successfully');
      }
      else if (pathname.match(/^\/api\/tasks\/[\w-]+$/)) {
        const taskId = pathname.split('/').pop();
        const taskIndex = mockTasks.findIndex(t => t.id === taskId);
        if (taskIndex !== -1) {
          mockTasks[taskIndex] = { ...mockTasks[taskIndex], ...body, updated_at: new Date().toISOString() };
          responseData = createApiResponse(mockTasks[taskIndex]);
          console.log(\`[\${timestamp}] -> Task updated: \${taskId}\`);
        }
      }
      else if (pathname.match(/^\/api\/projects\/[\w-]+$/)) {
        const projectId = pathname.split('/').pop();
        const projectIndex = mockProjects.findIndex(p => p.id === projectId);
        if (projectIndex !== -1) {
          mockProjects[projectIndex] = { ...mockProjects[projectIndex], ...body, updated_at: new Date().toISOString() };
          responseData = createApiResponse(mockProjects[projectIndex]);
        }
      }
    }
    // POST endpoints
    else if (method === 'POST') {
      const body = await getRequestBody(req);

      if (pathname === '/api/auth/github/device/start') {
        // GitHub Device Flow: Start authentication
        const deviceCode = 'MOCK-DEVICE-' + Math.random().toString(36).substring(7).toUpperCase();
        const userCode = Math.random().toString(36).substring(2, 10).toUpperCase();
        responseData = createApiResponse({
          user_code: userCode,
          verification_uri: 'https://github.com/login/device',
          expires_in: 900,
          interval: 5
        });
        console.log(\`[\${timestamp}] -> GitHub Device Flow started: \${userCode}\`);
      }
      else if (pathname === '/api/auth/github/device/poll') {
        // GitHub Device Flow: Poll for authorization
        // Mock: Return AUTHORIZATION_PENDING for first 2 polls, then SUCCESS
        const randomNum = Math.random();
        let status;
        if (randomNum < 0.3) {
          status = 'SUCCESS';
        } else if (randomNum < 0.4) {
          status = 'SLOW_DOWN';
        } else {
          status = 'AUTHORIZATION_PENDING';
        }
        responseData = createApiResponse(status);
        console.log(\`[\${timestamp}] -> GitHub Device Flow poll: \${status}\`);
      }
      else if (pathname === '/api/mcp-config') {
        // Save MCP server configuration
        const profile = query.profile || 'default';
        console.log(\`[\${timestamp}] -> MCP config saved for profile: \${profile}\`, body);
        responseData = createApiResponse({
          success: true,
          message: 'MCP configuration saved successfully'
        });
      }
      else if (pathname === '/api/tasks') {
        const newTask = {
          id: 'task-' + Date.now(),
          ...body,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        mockTasks.push(newTask);
        responseData = createApiResponse(newTask);
        statusCode = 201;
      }
      else if (pathname === '/api/projects') {
        const newProject = {
          id: 'project-' + Date.now(),
          name: body.name || 'New Project',
          description: body.description || '',
          status: body.status || 'active',
          language: body.language || 'typescript',
          script_language: body.script_language || body.language || 'typescript',
          path: body.path || '/app/projects/' + Date.now(),
          directory: body.directory || body.path || '/app/projects/' + Date.now(),
          repository_url: body.repository_url || '',
          ai_agent_type: body.ai_agent_type || 'claude-code',
          settings: body.settings || {
            auto_commit: false,
            enable_ai: true,
            test_on_save: false
          },
          ...body,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        mockProjects.push(newProject);
        responseData = createApiResponse(newProject);
        statusCode = 201;
      }
      else if (pathname.match(/^\/api\/projects\/[\w-]+\/open-editor$/)) {
        const projectId = pathname.split('/')[3];
        responseData = createApiResponse({
          success: true,
          message: 'Mock server - IDE integration not available',
          project_id: projectId,
          editor_opened: false
        });
        console.log(\`[\${timestamp}] -> IDE open request for project: \${projectId}\`);
      }
      else if (pathname === '/api/templates') {
        const newTemplate = {
          id: 'template-' + Date.now(),
          ...body,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        mockTemplates.push(newTemplate);
        responseData = createApiResponse(newTemplate);
        statusCode = 201;
        console.log(\`[\${timestamp}] -> Template created: \${newTemplate.id}\`);
      }
      else if (pathname === '/api/tasks/create-and-start') {
        const newTask = {
          id: 'task-' + Date.now(),
          ...body,
          status: 'in_progress',
          started_at: new Date().toISOString(),
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        mockTasks.push(newTask);
        responseData = createApiResponse(newTask);
        statusCode = 201;
        console.log(\`[\${timestamp}] -> Task created and started: \${newTask.id}\`);
      }
      else if (pathname.match(/^\/api\/task-attempts\/[\w-]+\/stop$/)) {
        const attemptId = pathname.split('/')[3];
        responseData = createApiResponse({
          attempt_id: attemptId,
          status: 'stopped',
          stopped_at: new Date().toISOString(),
          message: 'Task attempt stopped successfully'
        });
        console.log(\`[\${timestamp}] -> Task attempt stopped: \${attemptId}\`);
      }
    }
    // DELETE endpoints
    else if (method === 'DELETE') {
      if (pathname.match(/^\/api\/tasks\/[\w-]+$/)) {
        const taskId = pathname.split('/').pop();
        const taskIndex = mockTasks.findIndex(t => t.id === taskId);
        if (taskIndex !== -1) {
          const deletedTask = mockTasks.splice(taskIndex, 1)[0];
          responseData = createApiResponse(deletedTask);
        }
      }
      else if (pathname.match(/^\/api\/projects\/[\w-]+$/)) {
        const projectId = pathname.split('/').pop();
        const projectIndex = mockProjects.findIndex(p => p.id === projectId);
        if (projectIndex !== -1) {
          const deletedProject = mockProjects.splice(projectIndex, 1)[0];
          responseData = createApiResponse(deletedProject);
        }
      }
    }
  } catch (error) {
    console.error(\`[\${timestamp}] Error: \${error.message}\`);
    statusCode = 500;
    responseData = {success: false, message: 'Internal server error', error_data: {error: error.message}};
  }

  // Send response
  if (responseData) {
    console.log(\`[\${timestamp}] -> \${statusCode} OK - ApiResponse format\`);
    res.writeHead(statusCode, {'Content-Type': 'application/json'});
    res.end(JSON.stringify(responseData));
  } else if (pathname.startsWith('/api/')) {
    console.log(\`[\${timestamp}] -> 404 Not Found\`);
    res.writeHead(404, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({success: false, message: 'Endpoint not found', error_data: {path: pathname, query: query, method: method}}));
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(60));
  console.log('Mock API server running on port ' + PORT);
  console.log('Format: ApiResponse {success: true, data: ...}');
  console.log('Endpoints:');
  console.log('  - GET    /api/info');
  console.log('  - GET    /api/projects');
  console.log('  - GET    /api/projects/{id}');
  console.log('  - GET    /api/projects/{id}/branches');
  console.log('  - POST   /api/projects');
  console.log('  - POST   /api/projects/{id}/open-editor');
  console.log('  - PUT    /api/projects/{id}');
  console.log('  - DELETE /api/projects/{id}');
  console.log('  - GET    /api/templates?project_id={id}');
  console.log('  - GET    /api/templates?global=true');
  console.log('  - POST   /api/templates');
  console.log('  - GET    /api/tasks?project_id={id}');
  console.log('  - GET    /api/task-attempts?task_id={id}');
  console.log('  - GET    /api/task-attempts/{id}/branch-status');
  console.log('  - GET    /api/task-attempts/{id}/diff (SSE)');
  console.log('  - POST   /api/task-attempts/{id}/stop');
  console.log('  - GET    /api/execution-processes?task_attempt_id={id}');
  console.log('  - GET    /api/execution-processes/{id}');
  console.log('  - GET    /api/execution-processes/{id}/raw-logs (SSE)');
  console.log('  - GET    /api/execution-processes/{id}/normalized-logs (SSE)');
  console.log('  - GET    /api/images/task/{id}');
  console.log('  - POST   /api/tasks');
  console.log('  - POST   /api/tasks/create-and-start');
  console.log('  - PUT    /api/tasks/{id}');
  console.log('  - DELETE /api/tasks/{id}');
  console.log('  - GET    /api/profiles (returns file content)');
  console.log('  - PUT    /api/profiles (save file content)');
  console.log('  - GET    /api/mcp-config?profile={profile}');
  console.log('  - POST   /api/mcp-config?profile={profile}');
  console.log('  - GET    /api/auth/github/check');
  console.log('  - POST   /api/auth/github/device/start');
  console.log('  - POST   /api/auth/github/device/poll');
  console.log('  - GET    /api/filesystem/directory');
  console.log('  - PUT    /api/config (save config)');
  console.log('='.repeat(60));
});
" &

sleep 3

echo "Starting Vibe-Kanban Frontend on port 3000..."
cd /app/frontend && exec npm run dev -- --host 0.0.0.0 --port 3000
