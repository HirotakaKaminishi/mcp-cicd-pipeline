const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0'
  });
});

// Main application endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'MCP Sample Application',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// API endpoint
app.get('/api/status', (req, res) => {
  res.json({
    api: 'operational',
    server: 'mcp-server',
    uptime: process.uptime()
  });
});

app.listen(port, () => {
  console.log(`MCP Sample App listening on port ${port}`);
  console.log(`Health check: http://localhost:${port}/health`);
});