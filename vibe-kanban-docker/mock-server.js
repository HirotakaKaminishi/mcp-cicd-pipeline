// Vibe-Kanban Mock API Server
// Provides basic API responses to allow UI testing

const express = require('express');
const app = express();
const PORT = 3001;

app.use(express.json());

// CORS設定
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  next();
});

// Mock API endpoints
app.get('/api/info', (req, res) => {
  res.json({
    version: '0.0.68',
    environment: 'development'
  });
});

app.get('/api/projects', (req, res) => {
  res.json([
    {
      id: 'demo-project',
      name: 'Demo Project',
      description: 'Sample project for demonstration',
      created_at: new Date().toISOString()
    }
  ]);
});

app.get('/api/profiles', (req, res) => {
  res.json([
    {
      id: 'default',
      name: 'Default Profile',
      settings: {}
    }
  ]);
});

app.get('/api/auth/github/check', (req, res) => {
  res.json({
    authenticated: false,
    message: 'Mock server - GitHub auth not configured'
  });
});

app.get('/api/filesystem/directory', (req, res) => {
  res.json({
    path: '/app',
    directories: ['frontend', 'backend', 'shared'],
    files: ['package.json', 'README.md']
  });
});

// Catch all for other endpoints
app.all('/api/*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not mocked',
    path: req.path
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Mock API server running on port ${PORT}`);
  console.log('Available endpoints:');
  console.log('  - GET /api/info');
  console.log('  - GET /api/projects');
  console.log('  - GET /api/profiles');
  console.log('  - GET /api/auth/github/check');
  console.log('  - GET /api/filesystem/directory');
});