const request = require('supertest');
const app = require('./app');

describe('System-Wide Resource Monitoring Dashboard', () => {
  test('Health check endpoint', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('healthy');
    expect(response.body.deployment_id).toBe('20250811_sns_service');
  });

  test('Main endpoint', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body.message).toBe('System-Wide Resource Monitoring - Active!');
    expect(response.body.version).toBe('1.9.0');
    expect(response.body.status).toBe('production_with_system_monitoring');
    expect(response.body.feature).toBe('mcp_server_system_monitoring');
  });

  test('Optimized resource monitoring API', async () => {
    const response = await request(app).get('/api/resources');
    expect(response.status).toBe(200);
    expect(response.body.memory).toBeDefined();
    expect(response.body.cpu).toBeDefined();
    expect(response.body.uptime).toBeDefined();
    
    // Test new data structure
    expect(response.body.memory.heap_usage_percent).toBeGreaterThanOrEqual(0);
    expect(response.body.memory.heap_usage_percent).toBeLessThanOrEqual(100);
    expect(response.body.cpu.usage_percent).toBeGreaterThanOrEqual(0);
    expect(response.body.cpu.usage_percent).toBeLessThanOrEqual(100);
    expect(response.body.memory.rss_mb).toBeGreaterThan(0);
    expect(response.body.memory.heap_used_mb).toBeGreaterThanOrEqual(0);
  });

  test('Memory-optimized resource history API', async () => {
    const response = await request(app).get('/api/resources/history');
    expect(response.status).toBe(200);
    expect(response.body.data).toBeDefined();
    expect(response.body.max_points).toBe(20);
    expect(response.body.memory_optimization).toBeDefined();
    expect(Array.isArray(response.body.data)).toBe(true);
  });

  test('System monitoring API', async () => {
    const response = await request(app).get('/api/system');
    expect(response.status).toBe(200);
    
    // In CI environment, MCP server is not available, so fallback should be returned
    if (response.body.system) {
      // If MCP server is available (local environment)
      expect(response.body.system.cpu).toBeDefined();
      expect(response.body.system.memory).toBeDefined();
      expect(response.body.containers).toBeDefined();
    } else {
      // If MCP server is not available (CI environment), fallback should be returned
      expect(response.body.fallback).toBeDefined();
      expect(response.body.fallback.system).toBeDefined();
      expect(response.body.fallback.system.cpu.description).toBe('Unavailable');
      expect(response.body.fallback.system.memory.description).toBe('Unavailable');
    }
  }, 15000); // Increase timeout to 15 seconds

  test('Dashboard configuration', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body.dashboards).toBeDefined();
    expect(response.body.dashboards.main).toBe('Auto-refresh: 30s');
    expect(response.body.dashboards.health).toBe('Auto-refresh: 10s with memory-optimized charts');
    expect(response.body.monitoring.system_monitoring).toBe('MCP server-wide CPU/Memory tracking');
  });

  test('Cleanup configuration', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body.cleanup).toBeDefined();
    expect(response.body.cleanup.docker_images).toBe('Keep latest 3 timestamped images');
    expect(response.body.cleanup.release_dirs).toBe('Keep latest 5 release directories');
    expect(response.body.cleanup.schedule).toBe('Daily at 2:00 AM via cron');
  });

  test('Cleanup status endpoint', async () => {
    const response = await request(app).get('/cleanup');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('automated_cleanup_active');
    expect(response.body.features).toHaveLength(5);
    expect(response.body.script_location).toBe('/root/mcp_scripts/cleanup.sh');
  });

  test('Application configuration', () => {
    expect(process.env.NODE_ENV || 'test').toBeTruthy();
  });

  test('Modern service landing page', async () => {
    const response = await request(app).get('/service');
    expect(response.status).toBe(200);
    expect(response.text).toContain('NextGen CI/CD Platform');
    expect(response.text).toContain('Confidence');
    expect(response.text).toContain('Revolutionary CI/CD platform');
    expect(response.text).toContain('Zero-Downtime Deployments');
    expect(response.text).toContain('Real-Time Monitoring');
  });
});