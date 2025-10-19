// Mock API server for React App
import http from 'http';
import os from 'os';

const PORT = 3001;

// Mock data
const mockData = {
  '/api/health': {
    status: 'healthy',
    deployment_id: 'docker-compose-deployment',
    timestamp: new Date().toISOString(),
    services: {
      app: 'operational',
      database: 'operational',
      cache: 'operational'
    },
    metrics: {
      uptime: 3600,
      requests_per_minute: 125,
      error_rate: 0.1
    },
    system: {
      node_version: process.version,
      platform: process.platform,
      arch: process.arch,
      memory_usage: process.memoryUsage(),
      cpu_count: os.cpus().length
    }
  },
  '/api/resources/history': {
    data: Array.from({ length: 20 }, (_, i) => ({
      timestamp: new Date(Date.now() - (19 - i) * 30000).toISOString(),
      cpu_percent: Math.random() * 20 + 10,
      memory_percent: Math.random() * 30 + 20,
      server_cpu_percent: Math.random() * 15 + 5,
      server_memory_percent: Math.random() * 25 + 15
    }))
  },
  '/api/resources': {
    cpu: { usage_percent: Math.random() * 20 + 10 },
    memory: { heap_usage_percent: Math.random() * 30 + 20 }
  },
  '/api/server-stats': {
    system: {
      cpu: { usage_percent: Math.random() * 15 + 5 },
      memory: { usage_percent: Math.random() * 25 + 15 }
    }
  },
  '/api/containers': {
    containers: [
      { name: 'mcp-server', state: 'running' },
      { name: 'nginx-proxy', state: 'running' },
      { name: 'react-app', state: 'running' },
      { name: 'vibe-kanban', state: 'running' },
      { name: 'deployment-manager', state: 'running' }
    ]
  },
  '/api/nginx-status': {
    version: '1.29.0',
    features: ['security-headers', 'compression', 'caching', 'optimization']
  }
};

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  const path = req.url;

  // Update dynamic data
  if (path === '/api/resources') {
    mockData[path].cpu.usage_percent = Math.random() * 20 + 10;
    mockData[path].memory.heap_usage_percent = Math.random() * 30 + 20;
  }

  if (path === '/api/server-stats') {
    mockData[path].system.cpu.usage_percent = Math.random() * 15 + 5;
    mockData[path].system.memory.usage_percent = Math.random() * 25 + 15;
  }

  if (mockData[path]) {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify(mockData[path]));
  } else if (path.startsWith('/api/')) {
    res.writeHead(404, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({error: 'Endpoint not found', path: path}));
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Mock API server running on port ${PORT}`);
  console.log('Available endpoints:');
  Object.keys(mockData).forEach(endpoint => {
    console.log(`  - GET ${endpoint}`);
  });
});
