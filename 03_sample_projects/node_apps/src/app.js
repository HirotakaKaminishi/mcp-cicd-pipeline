// Optimized Resource Monitoring Dashboard - 20250811_optimized_monitoring
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Store resource history for charts (in production, use Redis or database)
let resourceHistory = [];
const MAX_HISTORY_POINTS = 20; // Reduced from 50 to 20 for memory efficiency

// Memory optimization: Clear history periodically
let historyCleanupCounter = 0;

// CPU usage tracking
let lastCpuUsage = process.cpuUsage();
let lastHrtime = process.hrtime();

// Application data
const appData = {
  message: 'System-Wide Resource Monitoring - Active!',
  version: '1.9.0',
  timestamp: '20250811_sns_service',
  deployment: 'Container-based CI/CD Pipeline',
  status: 'production_with_system_monitoring',
  feature: 'mcp_server_system_monitoring',
  cleanup: {
    docker_images: 'Keep latest 3 timestamped images',
    release_dirs: 'Keep latest 5 release directories',
    logs: 'Rotate deployment logs (100 entries)',
    schedule: 'Daily at 2:00 AM via cron'
  },
  dashboards: {
    main: 'Auto-refresh: 30s',
    api: 'Auto-refresh: 15s', 
    health: 'Auto-refresh: 10s with memory-optimized charts',
    cleanup: 'Auto-refresh: 20s'
  },
  monitoring: {
    cpu_calculation: 'Accurate process.cpuUsage() based',
    memory_tracking: 'Optimized heap and RSS monitoring',
    system_monitoring: 'MCP server-wide CPU/Memory tracking',
    update_frequency: '3 seconds',
    data_retention: '20 data points (reduced for efficiency)',
    memory_optimization: 'Lightweight data structures + periodic GC',
    mcp_integration: 'Real-time system stats via MCP API'
  }
};

// Chart-enabled HTML template function
function createHTMLDashboard(title, statusBadge, subtitle, content, refreshInterval = 30, includeCharts = false) {
  const chartScript = includeCharts ? `
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns/dist/chartjs-adapter-date-fns.bundle.min.js"></script>
  ` : '';
  
  return `
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title} - MCP CI/CD Pipeline</title>
    <meta http-equiv="refresh" content="${refreshInterval}">
    <style>
        /* Grafana-inspired Dark Theme */
        * {
            box-sizing: border-box;
        }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            background: #0b0c0e;
            margin: 0;
            padding: 20px;
            min-height: 100vh;
            color: #d9d9d9;
            line-height: 1.5;
        }
        .container {
            background: #141619;
            border: 1px solid #2a2d32;
            border-radius: 8px;
            padding: 24px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.4);
            max-width: 1400px;
            width: 100%;
            margin: 0 auto;
        }
        .dashboard-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 32px;
            padding-bottom: 16px;
            border-bottom: 1px solid #2a2d32;
        }
        h1 {
            color: #ffffff;
            font-size: 28px;
            font-weight: 600;
            margin: 0;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .subtitle {
            color: #9aa0a6;
            font-size: 14px;
            margin: 8px 0 0 0;
        }
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: linear-gradient(90deg, #52c41a, #389e0d);
            color: white;
            padding: 6px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            box-shadow: 0 2px 4px rgba(82, 196, 26, 0.2);
        }
        .status-badge.warning {
            background: linear-gradient(90deg, #fa8c16, #d46b08);
            box-shadow: 0 2px 4px rgba(250, 140, 22, 0.2);
        }
        .status-badge.error {
            background: linear-gradient(90deg, #ff4d4f, #cf1322);
            box-shadow: 0 2px 4px rgba(255, 77, 79, 0.2);
        }
        .refresh-info {
            color: #6b7280;
            font-size: 12px;
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 16px;
            margin: 24px 0;
        }
        .info-card {
            background: #1f2937;
            border: 1px solid #374151;
            padding: 20px;
            border-radius: 8px;
            transition: all 0.2s ease;
            position: relative;
            overflow: hidden;
        }
        .info-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: #60a5fa;
        }
        .info-card.success::before {
            background: linear-gradient(180deg, #10b981, #059669);
        }
        .info-card.warning::before {
            background: linear-gradient(180deg, #f59e0b, #d97706);
        }
        .info-card.error::before {
            background: linear-gradient(180deg, #ef4444, #dc2626);
        }
        .info-card:hover {
            border-color: #4b5563;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        }
        .label {
            color: #9ca3af;
            font-size: 12px;
            margin-bottom: 8px;
            text-transform: uppercase;
            font-weight: 500;
            letter-spacing: 0.5px;
        }
        .value {
            color: #f9fafb;
            font-size: 18px;
            font-weight: 600;
            line-height: 1.2;
        }
        .value.small {
            font-size: 14px;
            color: #d1d5db;
            font-weight: 400;
        }
        .navigation {
            display: flex;
            justify-content: center;
            gap: 2px;
            margin-top: 32px;
            padding: 4px;
            background: #374151;
            border-radius: 8px;
            border: 1px solid #4b5563;
        }
        .nav-link {
            color: #d1d5db;
            text-decoration: none;
            padding: 10px 16px;
            border-radius: 6px;
            font-weight: 500;
            font-size: 14px;
            transition: all 0.2s ease;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .nav-link:hover {
            background: #4b5563;
            color: #ffffff;
        }
        .nav-link.current {
            background: #3b82f6;
            color: white;
            box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
        }
        .timestamp {
            text-align: center;
            color: #6b7280;
            font-size: 12px;
            margin-top: 24px;
            padding-top: 16px;
            border-top: 1px solid #374151;
        }
        .feature-list {
            list-style: none;
            padding: 0;
        }
        .feature-list li {
            padding: 5px 0;
            border-bottom: 1px solid #eee;
        }
        .feature-list li:last-child {
            border-bottom: none;
        }
        .json-data {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            overflow-x: auto;
            white-space: pre-wrap;
        }
        .metrics-section {
            margin: 32px 0;
        }
        .section-title {
            color: #ffffff;
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .chart-container {
            background: #1f2937;
            border: 1px solid #374151;
            padding: 20px;
            border-radius: 8px;
            margin: 16px 0;
            position: relative;
            height: 320px;
        }
        .chart-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 16px;
            margin: 16px 0;
        }
        .gauge-container {
            background: #1f2937;
            border: 1px solid #374151;
            padding: 16px;
            border-radius: 8px;
            text-align: center;
            position: relative;
            height: 200px;
            display: flex;
            flex-direction: column;
            justify-content: center;
            transition: all 0.2s ease;
        }
        .gauge-container:hover {
            border-color: #4b5563;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }
        .gauge-value {
            position: absolute;
            top: 60%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 24px;
            font-weight: 700;
            color: #ffffff;
            z-index: 10;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        .chart-title {
            font-weight: 600;
            margin-bottom: 12px;
            color: #ffffff;
            text-align: center;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
        }
    </style>
    ${chartScript}
</head>
<body>
    <div class="container">
        <div class="dashboard-header">
            <div>
                <h1>
                    <span style="color: #3b82f6;">📊</span>
                    ${title}
                </h1>
                <p class="subtitle">${subtitle}</p>
            </div>
            <div style="display: flex; align-items: center; gap: 16px;">
                ${statusBadge}
                <div class="refresh-info">
                    <span style="color: #10b981;">●</span>
                    Auto-refresh: ${refreshInterval}s
                </div>
            </div>
        </div>
        ${content}
        <div class="navigation">
            <a href="/" class="nav-link ${title.includes('Dashboard') ? 'current' : ''}">
                <span>🏠</span> Dashboard
            </a>
            <a href="/api" class="nav-link ${title.includes('API') ? 'current' : ''}">
                <span>📊</span> API Data
            </a>
            <a href="/health" class="nav-link ${title.includes('Health') ? 'current' : ''}">
                <span>💚</span> Health Check
            </a>
            <a href="/cleanup" class="nav-link ${title.includes('Cleanup') ? 'current' : ''}">
                <span>♻️</span> Cleanup Status
            </a>
        </div>
        <div class="timestamp">
            Last updated: ${new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })}
        </div>
    </div>
</body>
</html>
  `;
}

app.get('/', (req, res) => {
  // Check if browser request (Accept header contains text/html)
  if (req.headers.accept && req.headers.accept.includes('text/html')) {
    const content = `
        <div class="info-grid">
            <div class="info-card">
                <div class="label">Version</div>
                <div class="value">${appData.version}</div>
            </div>
            <div class="info-card">
                <div class="label">Deployment ID</div>
                <div class="value">${appData.timestamp}</div>
            </div>
            <div class="info-card success">
                <div class="label">Status</div>
                <div class="value">${appData.status.replace(/_/g, ' ')}</div>
            </div>
            <div class="info-card">
                <div class="label">Environment</div>
                <div class="value">Docker Container</div>
            </div>
        </div>
        
        <div class="info-card">
            <div class="label">Message</div>
            <div class="value">${appData.message}</div>
        </div>
        
        <div class="info-card" style="margin-top: 20px;">
            <div class="label">Feature</div>
            <div class="value">${appData.feature.replace(/_/g, ' ')}</div>
        </div>
        
        <div class="info-card success" style="margin-top: 20px;">
            <div class="label">🧹 Automated Cleanup</div>
            <div class="value small">
                <div style="margin: 8px 0;">📦 Images: ${appData.cleanup.docker_images}</div>
                <div style="margin: 8px 0;">📁 Releases: ${appData.cleanup.release_dirs}</div>
                <div style="margin: 8px 0;">📜 Logs: ${appData.cleanup.logs}</div>
                <div style="margin: 8px 0;">⏰ Schedule: ${appData.cleanup.schedule}</div>
            </div>
        </div>
        
        <div class="info-card" style="margin-top: 20px; border-left: 4px solid #667eea;">
            <div class="label">📊 Dashboard Auto-Refresh</div>
            <div class="value small">
                <div style="margin: 8px 0;">🏠 Main: ${appData.dashboards.main}</div>
                <div style="margin: 8px 0;">📊 API Data: ${appData.dashboards.api}</div>
                <div style="margin: 8px 0;">💚 Health: ${appData.dashboards.health}</div>
                <div style="margin: 8px 0;">♻️ Cleanup: ${appData.dashboards.cleanup}</div>
            </div>
        </div>
    `;
    
    res.send(createHTMLDashboard(
      '🚀 MCP CI/CD Pipeline Dashboard',
      '<span class="status-badge">✅ LIVE - Production</span>',
      'Zero-Downtime Deployment with System-Wide Monitoring',
      content,
      30
    ));
  } else {
    // Return JSON for API clients
    res.json(appData);
  }
});

// API endpoint
app.get('/api', (req, res) => {
  // Check if browser request (Accept header contains text/html)
  if (req.headers.accept && req.headers.accept.includes('text/html')) {
    const content = `
        <div class="info-grid">
            <div class="info-card">
                <div class="label">API Version</div>
                <div class="value">${appData.version}</div>
            </div>
            <div class="info-card">
                <div class="label">Response Format</div>
                <div class="value">JSON</div>
            </div>
            <div class="info-card success">
                <div class="label">Status</div>
                <div class="value">Active</div>
            </div>
            <div class="info-card">
                <div class="label">Content-Type</div>
                <div class="value">application/json</div>
            </div>
        </div>
        
        <div class="info-card">
            <div class="label">📊 Raw JSON Data</div>
            <div class="json-data">${JSON.stringify(appData, null, 2)}</div>
        </div>
        
        <div class="info-card" style="margin-top: 20px;">
            <div class="label">Available Endpoints</div>
            <ul class="feature-list">
                <li><strong>GET /</strong> - Main dashboard (HTML/JSON)</li>
                <li><strong>GET /api</strong> - API data endpoint (current)</li>
                <li><strong>GET /health</strong> - Health check endpoint</li>
                <li><strong>GET /cleanup</strong> - Cleanup status endpoint</li>
            </ul>
        </div>
    `;
    
    res.send(createHTMLDashboard(
      '📊 API Data Dashboard',
      '<span class="status-badge">✅ API Active</span>',
      'Application Programming Interface - Data Endpoint',
      content,
      15
    ));
  } else {
    res.json(appData);
  }
});

app.get('/health', (req, res) => {
  const healthData = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    deployment_id: appData.timestamp,
    uptime: process.uptime(),
    memory_usage: process.memoryUsage(),
    version: process.version,
    platform: process.platform
  };
  
  // Check if browser request (Accept header contains text/html)
  if (req.headers.accept && req.headers.accept.includes('text/html')) {
    const uptimeHours = Math.floor(healthData.uptime / 3600);
    const uptimeMinutes = Math.floor((healthData.uptime % 3600) / 60);
    const uptimeSeconds = Math.floor(healthData.uptime % 60);
    const memoryMB = Math.round(healthData.memory_usage.rss / 1024 / 1024);
    const memoryUsagePercent = Math.round((healthData.memory_usage.heapUsed / healthData.memory_usage.heapTotal) * 100);
    
    const content = `
        <div class="info-grid">
            <div class="info-card success">
                <div class="label">Health Status</div>
                <div class="value">✅ ${healthData.status.toUpperCase()}</div>
            </div>
            <div class="info-card">
                <div class="label">Uptime</div>
                <div class="value">${uptimeHours}h ${uptimeMinutes}m ${uptimeSeconds}s</div>
            </div>
            <div class="info-card">
                <div class="label">Memory Usage</div>
                <div class="value">${memoryMB} MB</div>
            </div>
            <div class="info-card">
                <div class="label">Node.js Version</div>
                <div class="value">${healthData.version}</div>
            </div>
        </div>
        
        <div class="metrics-section">
            <div class="section-title">
                <span>📈</span>
                Real-time Resource Metrics
            </div>
            <div class="chart-grid">
                <div class="gauge-container">
                    <div class="chart-title">
                        <span>💾</span>
                        App Memory Usage
                    </div>
                    <canvas id="memoryGauge"></canvas>
                    <div class="gauge-value" id="memoryValue">${memoryUsagePercent}%</div>
                </div>
                <div class="gauge-container">
                    <div class="chart-title">
                        <span>🖥️</span>
                        App CPU Usage
                    </div>
                    <canvas id="cpuGauge"></canvas>
                    <div class="gauge-value" id="cpuValue">Loading...</div>
                </div>
                <div class="gauge-container">
                    <div class="chart-title">
                        <span>🌐</span>
                        Server Memory
                    </div>
                    <canvas id="systemMemoryGauge"></canvas>
                    <div class="gauge-value" id="systemMemoryValue">Loading...</div>
                </div>
                <div class="gauge-container">
                    <div class="chart-title">
                        <span>⚡</span>
                        Server CPU
                    </div>
                    <canvas id="systemCpuGauge"></canvas>
                    <div class="gauge-value" id="systemCpuValue">Loading...</div>
                </div>
            </div>
        </div>
        
        <div class="metrics-section">
            <div class="section-title">
                <span>📈</span>
                Resource Usage Timeline
            </div>
            <div class="chart-container">
                <canvas id="resourceChart"></canvas>
            </div>
        </div>
        
        <div class="info-card">
            <div class="label">🚀 Deployment Information</div>
            <div class="value small">
                <div style="margin: 8px 0;"><strong>Deployment ID:</strong> ${healthData.deployment_id}</div>
                <div style="margin: 8px 0;"><strong>Platform:</strong> ${healthData.platform}</div>
                <div style="margin: 8px 0;"><strong>Started At:</strong> ${new Date(Date.now() - healthData.uptime * 1000).toLocaleString('ja-JP')}</div>
                <div style="margin: 8px 0;"><strong>Process ID:</strong> ${process.pid}</div>
            </div>
        </div>
        
        <script>
        let memoryChart, cpuChart, resourceChart, systemMemoryChart, systemCpuChart;
        let resourceData = [];
        let systemData = [];
        
        function createGaugeChart(ctx, label, value, maxValue = 100) {
            return new Chart(ctx, {
                type: 'doughnut',
                data: {
                    datasets: [{
                        data: [value, maxValue - value],
                        backgroundColor: [
                            value > 80 ? '#f44336' : value > 60 ? '#FF9800' : '#4CAF50',
                            '#e0e0e0'
                        ],
                        borderWidth: 0
                    }]
                },
                options: {
                    cutout: '75%',
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: { enabled: false }
                    },
                    animation: { animateRotate: true }
                }
            });
        }
        
        function createResourceChart(ctx) {
            return new Chart(ctx, {
                type: 'line',
                data: {
                    labels: [],
                    datasets: [{
                        label: 'Memory Usage (%)',
                        data: [],
                        borderColor: '#4CAF50',
                        backgroundColor: 'rgba(76, 175, 80, 0.1)',
                        tension: 0.4
                    }, {
                        label: 'CPU Usage (%)',
                        data: [],
                        borderColor: '#2196F3',
                        backgroundColor: 'rgba(33, 150, 243, 0.1)',
                        tension: 0.4
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: { beginAtZero: true, max: 100 },
                        x: { type: 'time', time: { unit: 'minute' } }
                    },
                    plugins: {
                        legend: { position: 'top' }
                    },
                    animation: { duration: 1000 }
                }
            });
        }
        
        function updateCharts() {
            fetch('/api/resources')
                .then(response => response.json())
                .then(data => {
                    // Update gauges with new data structure
                    if (memoryChart) {
                        const memoryPercent = data.memory.heap_usage_percent || 0;
                        memoryChart.data.datasets[0].data = [memoryPercent, 100 - memoryPercent];
                        memoryChart.data.datasets[0].backgroundColor[0] = 
                            memoryPercent > 80 ? '#f44336' : 
                            memoryPercent > 60 ? '#FF9800' : '#4CAF50';
                        memoryChart.update('none');
                        document.getElementById('memoryValue').textContent = memoryPercent + '%';
                    }
                    
                    if (cpuChart) {
                        const cpuPercent = data.cpu.usage_percent || 0;
                        cpuChart.data.datasets[0].data = [cpuPercent, 100 - cpuPercent];
                        cpuChart.data.datasets[0].backgroundColor[0] = 
                            cpuPercent > 80 ? '#f44336' : 
                            cpuPercent > 60 ? '#FF9800' : '#4CAF50';
                        cpuChart.update('none');
                        document.getElementById('cpuValue').textContent = cpuPercent.toFixed(1) + '%';
                    }
                    
                    // Update timeline chart with memory-optimized data
                    resourceData.push({
                        timestamp: data.timestamp,
                        memory_percent: data.memory.heap_usage_percent || 0,
                        cpu_percent: data.cpu.usage_percent || 0
                    });
                    
                    // Keep only last 15 points in browser for performance
                    if (resourceData.length > 15) resourceData.shift();
                    
                    if (resourceChart) {
                        resourceChart.data.labels = resourceData.map(d => new Date(d.timestamp));
                        resourceChart.data.datasets[0].data = resourceData.map(d => d.memory_percent);
                        resourceChart.data.datasets[1].data = resourceData.map(d => d.cpu_percent);
                        resourceChart.update('none');
                    }
                })
                .catch(error => console.error('Error updating charts:', error));
            
            // Update system-wide monitoring
            fetch('/api/system')
                .then(response => response.json())
                .then(data => {
                    // Update system memory gauge
                    if (systemMemoryChart) {
                        const systemMemoryPercent = data.system?.memory?.usage_percent || 0;
                        systemMemoryChart.data.datasets[0].data = [systemMemoryPercent, 100 - systemMemoryPercent];
                        systemMemoryChart.data.datasets[0].backgroundColor[0] = 
                            systemMemoryPercent > 80 ? '#f44336' : 
                            systemMemoryPercent > 60 ? '#FF9800' : '#4CAF50';
                        systemMemoryChart.update('none');
                        document.getElementById('systemMemoryValue').textContent = systemMemoryPercent + '%';
                    }
                    
                    // Update system CPU gauge
                    if (systemCpuChart) {
                        const systemCpuPercent = data.system?.cpu?.usage_percent || 0;
                        systemCpuChart.data.datasets[0].data = [systemCpuPercent, 100 - systemCpuPercent];
                        systemCpuChart.data.datasets[0].backgroundColor[0] = 
                            systemCpuPercent > 80 ? '#f44336' : 
                            systemCpuPercent > 60 ? '#FF9800' : '#4CAF50';
                        systemCpuChart.update('none');
                        document.getElementById('systemCpuValue').textContent = systemCpuPercent.toFixed(1) + '%';
                    }
                    
                    // Update system timeline data
                    if (data.system) {
                        systemData.push({
                            timestamp: data.timestamp,
                            system_memory_percent: data.system.memory.usage_percent || 0,
                            system_cpu_percent: data.system.cpu.usage_percent || 0
                        });
                        
                        // Keep only last 15 points in browser for performance
                        if (systemData.length > 15) systemData.shift();
                        
                        // Update resource chart with system data
                        if (resourceChart && systemData.length > 0) {
                            // Add system data as additional datasets
                            if (resourceChart.data.datasets.length < 4) {
                                resourceChart.data.datasets.push({
                                    label: 'Server Memory (%)',
                                    data: [],
                                    borderColor: '#9C27B0',
                                    backgroundColor: 'rgba(156, 39, 176, 0.1)',
                                    tension: 0.4
                                });
                                resourceChart.data.datasets.push({
                                    label: 'Server CPU (%)',
                                    data: [],
                                    borderColor: '#FF5722',
                                    backgroundColor: 'rgba(255, 87, 34, 0.1)',
                                    tension: 0.4
                                });
                            }
                            
                            resourceChart.data.datasets[2].data = systemData.map(d => d.system_memory_percent);
                            resourceChart.data.datasets[3].data = systemData.map(d => d.system_cpu_percent);
                            resourceChart.update('none');
                        }
                    }
                })
                .catch(error => {
                    console.error('Error updating system charts:', error);
                    // Set fallback values for system charts
                    if (document.getElementById('systemMemoryValue')) {
                        document.getElementById('systemMemoryValue').textContent = 'N/A';
                    }
                    if (document.getElementById('systemCpuValue')) {
                        document.getElementById('systemCpuValue').textContent = 'N/A';
                    }
                });
        }
        
        // Initialize charts
        document.addEventListener('DOMContentLoaded', function() {
            const memoryCtx = document.getElementById('memoryGauge').getContext('2d');
            const cpuCtx = document.getElementById('cpuGauge').getContext('2d');
            const systemMemoryCtx = document.getElementById('systemMemoryGauge').getContext('2d');
            const systemCpuCtx = document.getElementById('systemCpuGauge').getContext('2d');
            const resourceCtx = document.getElementById('resourceChart').getContext('2d');
            
            memoryChart = createGaugeChart(memoryCtx, 'App Memory', ${memoryUsagePercent});
            cpuChart = createGaugeChart(cpuCtx, 'App CPU', 0);
            systemMemoryChart = createGaugeChart(systemMemoryCtx, 'System Memory', 0);
            systemCpuChart = createGaugeChart(systemCpuCtx, 'System CPU', 0);
            resourceChart = createResourceChart(resourceCtx);
            
            // Initial update
            updateCharts();
            
            // Update every 3 seconds
            setInterval(updateCharts, 3000);
        });
        </script>
    `;
    
    res.send(createHTMLDashboard(
      '💚 Health Check Dashboard',
      '<span class="status-badge">✅ System Healthy</span>',
      'Real-time App & MCP Server System Monitoring',
      content,
      10,
      true // Include Chart.js
    ));
  } else {
    res.json(healthData);
  }
});

app.get('/cleanup', (req, res) => {
  const cleanupData = {
    cleanup_config: appData.cleanup,
    status: 'automated_cleanup_active',
    description: 'Automated cleanup prevents disk space bloat by rotating old files',
    features: [
      'Docker image rotation (keep latest 3)',
      'Release directory cleanup (keep latest 5)', 
      'Log rotation (keep 100 entries)',
      'Daily automated execution via cron',
      'Dangling image pruning'
    ],
    next_scheduled: 'Daily at 2:00 AM server time',
    manual_trigger: 'Available via /root/mcp_scripts/cleanup.sh',
    script_location: '/root/mcp_scripts/cleanup.sh',
    log_file: '/root/mcp_project/cleanup.log'
  };
  
  // Check if browser request (Accept header contains text/html)
  if (req.headers.accept && req.headers.accept.includes('text/html')) {
    const content = `
        <div class="info-grid">
            <div class="info-card success">
                <div class="label">Cleanup Status</div>
                <div class="value">🧹 ACTIVE</div>
            </div>
            <div class="info-card">
                <div class="label">Schedule</div>
                <div class="value">Daily 2:00 AM</div>
            </div>
            <div class="info-card">
                <div class="label">Docker Images</div>
                <div class="value">Keep Latest 3</div>
            </div>
            <div class="info-card">
                <div class="label">Release Dirs</div>
                <div class="value">Keep Latest 5</div>
            </div>
        </div>
        
        <div class="info-card success">
            <div class="label">🎯 Cleanup Configuration</div>
            <div class="value small">
                <div style="margin: 8px 0;">📦 <strong>Images:</strong> ${appData.cleanup.docker_images}</div>
                <div style="margin: 8px 0;">📁 <strong>Releases:</strong> ${appData.cleanup.release_dirs}</div>
                <div style="margin: 8px 0;">📜 <strong>Logs:</strong> ${appData.cleanup.logs}</div>
                <div style="margin: 8px 0;">⏰ <strong>Schedule:</strong> ${appData.cleanup.schedule}</div>
            </div>
        </div>
        
        <div class="info-card" style="margin-top: 20px;">
            <div class="label">⚡ Automated Features</div>
            <ul class="feature-list">
                ${cleanupData.features.map(feature => `<li>✅ ${feature}</li>`).join('')}
            </ul>
        </div>
        
        <div class="info-card" style="margin-top: 20px;">
            <div class="label">🔧 Management Information</div>
            <div class="value small">
                <div style="margin: 8px 0;"><strong>Script Location:</strong> <code>${cleanupData.script_location}</code></div>
                <div style="margin: 8px 0;"><strong>Log File:</strong> <code>${cleanupData.log_file}</code></div>
                <div style="margin: 8px 0;"><strong>Manual Trigger:</strong> <code>${cleanupData.manual_trigger}</code></div>
                <div style="margin: 8px 0;"><strong>Next Scheduled:</strong> ${cleanupData.next_scheduled}</div>
            </div>
        </div>
        
        <div class="info-card" style="margin-top: 20px;">
            <div class="label">💡 Description</div>
            <div class="value small">${cleanupData.description}</div>
        </div>
        
        <div class="info-card" style="margin-top: 20px;">
            <div class="label">📊 Raw Cleanup Data</div>
            <div class="json-data">${JSON.stringify(cleanupData, null, 2)}</div>
        </div>
    `;
    
    res.send(createHTMLDashboard(
      '♻️ Cleanup Status Dashboard',
      '<span class="status-badge">✅ Cleanup Active</span>',
      'Automated Cleanup System - Disk Space Management',
      content,
      20
    ));
  } else {
    res.json(cleanupData);
  }
});

// Resource monitoring API for charts
app.get('/api/resources', (req, res) => {
  const currentTime = new Date().toISOString();
  const memoryUsage = process.memoryUsage();
  const uptime = process.uptime();
  
  // Calculate accurate CPU usage
  const currentCpuUsage = process.cpuUsage();
  const currentHrtime = process.hrtime();
  
  // Calculate CPU percentage based on time difference
  const cpuDelta = {
    user: currentCpuUsage.user - lastCpuUsage.user,
    system: currentCpuUsage.system - lastCpuUsage.system
  };
  
  const timeDelta = currentHrtime[0] - lastHrtime[0] + (currentHrtime[1] - lastHrtime[1]) / 1e9;
  const cpuPercent = timeDelta > 0 ? Math.min(100, ((cpuDelta.user + cpuDelta.system) / 1000000) / timeDelta * 100) : 0;
  
  // Update for next calculation
  lastCpuUsage = currentCpuUsage;
  lastHrtime = currentHrtime;
  
  // Calculate memory usage more accurately
  const memoryUsedMB = Math.round(memoryUsage.rss / 1024 / 1024);
  const heapUsedMB = Math.round(memoryUsage.heapUsed / 1024 / 1024);
  const heapTotalMB = Math.round(memoryUsage.heapTotal / 1024 / 1024);
  const heapUsagePercent = heapTotalMB > 0 ? Math.round((memoryUsage.heapUsed / memoryUsage.heapTotal) * 100) : 0;
  
  const resourceData = {
    timestamp: currentTime,
    memory: {
      rss_mb: memoryUsedMB,
      heap_used_mb: heapUsedMB,
      heap_total_mb: heapTotalMB,
      heap_usage_percent: heapUsagePercent,
      external_mb: Math.round(memoryUsage.external / 1024 / 1024)
    },
    cpu: {
      usage_percent: Math.round(cpuPercent * 100) / 100,
      user_time_ms: Math.round(currentCpuUsage.user / 1000),
      system_time_ms: Math.round(currentCpuUsage.system / 1000)
    },
    uptime: {
      seconds: Math.round(uptime),
      minutes: Math.round(uptime / 60 * 100) / 100,
      hours: Math.round(uptime / 3600 * 100) / 100
    },
    process: {
      pid: process.pid,
      version: process.version,
      platform: process.platform,
      arch: process.arch
    }
  };
  
  // Store in history for line charts with memory optimization
  resourceHistory.push({
    timestamp: resourceData.timestamp,
    memory_percent: resourceData.memory.heap_usage_percent,
    cpu_percent: resourceData.cpu.usage_percent
  });
  
  if (resourceHistory.length > MAX_HISTORY_POINTS) {
    resourceHistory.shift();
  }
  
  // Periodic memory cleanup
  historyCleanupCounter++;
  if (historyCleanupCounter % 100 === 0) {
    // Force garbage collection periodically (if available)
    if (global.gc) {
      global.gc();
    }
    // Reset counter
    historyCleanupCounter = 0;
  }
  
  res.json(resourceData);
});

// Resource history API for line charts
app.get('/api/resources/history', (req, res) => {
  res.json({
    data: resourceHistory,
    length: resourceHistory.length,
    max_points: MAX_HISTORY_POINTS,
    memory_optimization: 'Lightweight data structure with reduced retention'
  });
});

// MCP Server system-wide monitoring API
app.get('/api/system', async (req, res) => {
  try {
    // Get system-wide CPU and memory information via MCP API
    const mcpServerUrl = process.env.MCP_SERVER_URL || 'http://192.168.111.200:8080';
    
    // Create timeout controller for CI environment
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout
    
    const systemInfoResponse = await fetch(mcpServerUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'execute_command',
        params: {
          command: 'top -b -n1 | head -5 && echo \'---\' && docker stats --no-stream --format \'table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\\t{{.MemPerc}}\''
        },
        id: 1
      }),
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);

    if (!systemInfoResponse.ok) {
      throw new Error('Failed to fetch system info from MCP server');
    }

    const systemData = await systemInfoResponse.json();
    const output = systemData.result?.stdout || '';
    
    // Parse system info
    const lines = output.split('\n');
    let systemCpu = 0;
    let systemMemoryUsed = 0;
    let systemMemoryTotal = 0;
    let containerStats = [];

    for (const line of lines) {
      // Parse CPU info
      if (line.includes('%Cpu(s):')) {
        const cpuMatch = line.match(/(\d+\.\d+)\s+us/);
        if (cpuMatch) systemCpu = parseFloat(cpuMatch[1]);
      }
      
      // Parse memory info
      if (line.includes('MiB Mem')) {
        const memMatch = line.match(/(\d+\.\d+)\s+total,\s+\d+\.\d+\s+free,\s+(\d+\.\d+)\s+used/);
        if (memMatch) {
          systemMemoryTotal = parseFloat(memMatch[1]);
          systemMemoryUsed = parseFloat(memMatch[2]);
        }
      }
      
      // Parse Docker container stats
      if (line.includes('mcp-') && !line.includes('NAME')) {
        const parts = line.split(/\s+/);
        if (parts.length >= 4) {
          containerStats.push({
            name: parts[0],
            cpu_percent: parseFloat(parts[1].replace('%', '') || '0'),
            memory_usage: parts[2],
            memory_percent: parseFloat(parts[3].replace('%', '') || '0')
          });
        }
      }
    }

    const systemInfo = {
      timestamp: new Date().toISOString(),
      system: {
        cpu: {
          usage_percent: systemCpu,
          description: 'System-wide CPU usage'
        },
        memory: {
          total_mb: systemMemoryTotal,
          used_mb: systemMemoryUsed,
          usage_percent: systemMemoryTotal > 0 ? Math.round((systemMemoryUsed / systemMemoryTotal) * 100) : 0,
          available_mb: systemMemoryTotal - systemMemoryUsed,
          description: 'System-wide memory usage'
        }
      },
      containers: containerStats,
      source: 'MCP Server via top and docker stats'
    };

    res.json(systemInfo);
  } catch (error) {
    console.error('System monitoring error:', error);
    // Return 200 with fallback data instead of 500 error
    res.json({
      timestamp: new Date().toISOString(),
      fallback: {
        system: {
          cpu: { usage_percent: 0, description: 'Unavailable' },
          memory: { usage_percent: 0, description: 'Unavailable' }
        },
        containers: [],
        source: 'Fallback - MCP server unreachable'
      },
      error_info: {
        message: error.message,
        type: error.name || 'Unknown'
      }
    });
  }
});

// Modern SNS-style Service Landing Page
app.get('/service', (req, res) => {
  const content = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NextGen CI/CD Platform - Transform Your Development Workflow</title>
    <meta name="description" content="Revolutionary cloud-native CI/CD platform with real-time monitoring, automated deployments, and intelligent insights.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        /* Modern SNS-inspired Design System */
        :root {
            --primary-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --accent-gradient: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            --success-gradient: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            --warning-gradient: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
            --dark-bg: #0a0a0b;
            --card-bg: #1a1a1b;
            --border-color: #343536;
            --text-primary: #ffffff;
            --text-secondary: #a8a8a8;
            --text-muted: #6b6c70;
            --glass-bg: rgba(26, 26, 27, 0.8);
            --shadow-soft: 0 4px 20px rgba(0, 0, 0, 0.15);
            --shadow-strong: 0 10px 40px rgba(0, 0, 0, 0.3);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--dark-bg);
            color: var(--text-primary);
            line-height: 1.6;
            overflow-x: hidden;
        }

        /* Animated Background */
        .bg-animation {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: -1;
            background: var(--dark-bg);
        }

        .bg-animation::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: 
                radial-gradient(600px circle at 20% 30%, rgba(102, 126, 234, 0.1), transparent),
                radial-gradient(800px circle at 80% 70%, rgba(118, 75, 162, 0.1), transparent),
                radial-gradient(400px circle at 40% 80%, rgba(240, 147, 251, 0.08), transparent);
            animation: float 20s ease-in-out infinite;
        }

        @keyframes float {
            0%, 100% { transform: translateY(0px) rotate(0deg); }
            33% { transform: translateY(-20px) rotate(1deg); }
            66% { transform: translateY(-10px) rotate(-1deg); }
        }

        /* Navigation */
        .navbar {
            position: fixed;
            top: 0;
            width: 100%;
            padding: 20px 0;
            background: var(--glass-bg);
            backdrop-filter: blur(20px);
            border-bottom: 1px solid var(--border-color);
            z-index: 1000;
            transition: all 0.3s ease;
        }

        .navbar.scrolled {
            padding: 15px 0;
            background: rgba(10, 10, 11, 0.95);
        }

        .nav-container {
            max-width: 1200px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0 20px;
        }

        .logo {
            font-size: 24px;
            font-weight: 800;
            background: var(--primary-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .nav-links {
            display: flex;
            gap: 30px;
            align-items: center;
        }

        .nav-link {
            color: var(--text-secondary);
            text-decoration: none;
            font-weight: 500;
            transition: all 0.3s ease;
            position: relative;
        }

        .nav-link:hover {
            color: var(--text-primary);
        }

        .nav-link::after {
            content: '';
            position: absolute;
            bottom: -5px;
            left: 0;
            width: 0;
            height: 2px;
            background: var(--primary-gradient);
            transition: width 0.3s ease;
        }

        .nav-link:hover::after {
            width: 100%;
        }

        .cta-button {
            background: var(--primary-gradient);
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 50px;
            font-weight: 600;
            text-decoration: none;
            transition: all 0.3s ease;
            box-shadow: var(--shadow-soft);
        }

        .cta-button:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-strong);
        }

        /* Hero Section */
        .hero {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            text-align: center;
            padding: 120px 20px 80px;
        }

        .hero-content {
            max-width: 800px;
        }

        .hero-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: var(--glass-bg);
            border: 1px solid var(--border-color);
            padding: 8px 16px;
            border-radius: 50px;
            font-size: 14px;
            font-weight: 500;
            margin-bottom: 30px;
            backdrop-filter: blur(10px);
        }

        .hero-title {
            font-size: clamp(48px, 8vw, 72px);
            font-weight: 800;
            line-height: 1.1;
            margin-bottom: 24px;
            background: linear-gradient(135deg, #ffffff 0%, #a8a8a8 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .hero-subtitle {
            font-size: clamp(18px, 3vw, 24px);
            color: var(--text-secondary);
            margin-bottom: 40px;
            font-weight: 400;
        }

        .hero-actions {
            display: flex;
            gap: 20px;
            justify-content: center;
            flex-wrap: wrap;
        }

        .btn-primary {
            background: var(--primary-gradient);
            color: white;
            padding: 16px 32px;
            border: none;
            border-radius: 50px;
            font-weight: 600;
            font-size: 16px;
            text-decoration: none;
            transition: all 0.3s ease;
            box-shadow: var(--shadow-soft);
            display: inline-flex;
            align-items: center;
            gap: 10px;
        }

        .btn-primary:hover {
            transform: translateY(-3px);
            box-shadow: var(--shadow-strong);
        }

        .btn-secondary {
            background: transparent;
            color: var(--text-primary);
            padding: 16px 32px;
            border: 2px solid var(--border-color);
            border-radius: 50px;
            font-weight: 600;
            font-size: 16px;
            text-decoration: none;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 10px;
        }

        .btn-secondary:hover {
            border-color: var(--text-primary);
            background: var(--glass-bg);
            backdrop-filter: blur(10px);
        }

        /* Features Section */
        .features {
            padding: 100px 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        .section-header {
            text-align: center;
            margin-bottom: 80px;
        }

        .section-title {
            font-size: clamp(32px, 5vw, 48px);
            font-weight: 700;
            margin-bottom: 16px;
        }

        .section-subtitle {
            font-size: 18px;
            color: var(--text-secondary);
            max-width: 600px;
            margin: 0 auto;
        }

        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
        }

        .feature-card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 20px;
            padding: 40px 30px;
            text-align: center;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .feature-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 2px;
            background: var(--primary-gradient);
            transform: scaleX(0);
            transition: transform 0.3s ease;
        }

        .feature-card:hover::before {
            transform: scaleX(1);
        }

        .feature-card:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-strong);
        }

        .feature-icon {
            width: 60px;
            height: 60px;
            margin: 0 auto 20px;
            background: var(--primary-gradient);
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
        }

        .feature-title {
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 12px;
        }

        .feature-description {
            color: var(--text-secondary);
            line-height: 1.6;
        }

        /* Stats Section */
        .stats {
            padding: 80px 20px;
            background: var(--card-bg);
            border-top: 1px solid var(--border-color);
            border-bottom: 1px solid var(--border-color);
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 40px;
            text-align: center;
        }

        .stat-item {
            padding: 20px;
        }

        .stat-number {
            font-size: 36px;
            font-weight: 800;
            background: var(--accent-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 8px;
        }

        .stat-label {
            color: var(--text-secondary);
            font-weight: 500;
        }

        /* Footer */
        .footer {
            padding: 60px 20px 40px;
            text-align: center;
        }

        .footer-content {
            max-width: 1200px;
            margin: 0 auto;
        }

        .footer-text {
            color: var(--text-muted);
            margin-bottom: 30px;
        }

        .footer-links {
            display: flex;
            justify-content: center;
            gap: 30px;
            flex-wrap: wrap;
            margin-bottom: 30px;
        }

        .footer-link {
            color: var(--text-secondary);
            text-decoration: none;
            transition: color 0.3s ease;
        }

        .footer-link:hover {
            color: var(--text-primary);
        }

        /* Mobile Responsive */
        @media (max-width: 768px) {
            .nav-links {
                display: none;
            }

            .hero-actions {
                flex-direction: column;
                align-items: center;
            }

            .btn-primary, .btn-secondary {
                width: 100%;
                max-width: 280px;
                justify-content: center;
            }

            .features-grid {
                grid-template-columns: 1fr;
            }

            .stats-grid {
                grid-template-columns: repeat(2, 1fr);
            }

            .footer-links {
                flex-direction: column;
                gap: 15px;
            }
        }
    </style>
</head>
<body>
    <div class="bg-animation"></div>
    
    <!-- Navigation -->
    <nav class="navbar" id="navbar">
        <div class="nav-container">
            <div class="logo">NextGen CI/CD</div>
            <div class="nav-links">
                <a href="#features" class="nav-link">Features</a>
                <a href="#stats" class="nav-link">Performance</a>
                <a href="/health" class="nav-link">Monitor</a>
                <a href="/" class="cta-button">Dashboard</a>
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <section class="hero">
        <div class="hero-content">
            <div class="hero-badge">
                <span style="background: linear-gradient(135deg, #10b981, #059669); width: 8px; height: 8px; border-radius: 50%; display: block;"></span>
                Live & Production Ready
            </div>
            <h1 class="hero-title">
                Deploy with
                <br>
                <span style="background: var(--primary-gradient); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;">Confidence</span>
            </h1>
            <p class="hero-subtitle">
                Revolutionary CI/CD platform with real-time monitoring, automated deployments, 
                and intelligent insights. Built for modern development teams.
            </p>
            <div class="hero-actions">
                <a href="/health" class="btn-primary">
                    <span>🚀</span>
                    View Live Dashboard
                </a>
                <a href="#features" class="btn-secondary">
                    <span>📋</span>
                    Explore Features
                </a>
            </div>
        </div>
    </section>

    <!-- Features Section -->
    <section class="features" id="features">
        <div class="container">
            <div class="section-header">
                <h2 class="section-title">Powerful Features</h2>
                <p class="section-subtitle">
                    Everything you need to streamline your development workflow with cutting-edge technology
                </p>
            </div>
            <div class="features-grid">
                <div class="feature-card">
                    <div class="feature-icon">🔄</div>
                    <h3 class="feature-title">Zero-Downtime Deployments</h3>
                    <p class="feature-description">
                        Seamless container-based deployments with intelligent rollback capabilities. 
                        Deploy with confidence knowing your users won't experience any downtime.
                    </p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">📊</div>
                    <h3 class="feature-title">Real-Time Monitoring</h3>
                    <p class="feature-description">
                        Advanced system monitoring with beautiful Grafana-inspired dashboards. 
                        Track CPU, memory, and custom metrics in real-time.
                    </p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">🤖</div>
                    <h3 class="feature-title">Intelligent Automation</h3>
                    <p class="feature-description">
                        AI-powered deployment optimization with automated testing, 
                        security scanning, and performance analysis.
                    </p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">🔒</div>
                    <h3 class="feature-title">Enterprise Security</h3>
                    <p class="feature-description">
                        Built-in security best practices with automated vulnerability scanning, 
                        secret management, and compliance monitoring.
                    </p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">⚡</div>
                    <h3 class="feature-title">Lightning Fast</h3>
                    <p class="feature-description">
                        Optimized for speed with parallel processing, intelligent caching, 
                        and distributed build systems for maximum performance.
                    </p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">🌐</div>
                    <h3 class="feature-title">Global Scale</h3>
                    <p class="feature-description">
                        Multi-region deployments with CDN integration and edge computing 
                        capabilities for worldwide performance.
                    </p>
                </div>
            </div>
        </div>
    </section>

    <!-- Stats Section -->
    <section class="stats" id="stats">
        <div class="container">
            <div class="stats-grid">
                <div class="stat-item">
                    <div class="stat-number">99.9%</div>
                    <div class="stat-label">Uptime Guarantee</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">50ms</div>
                    <div class="stat-label">Average Response Time</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">10M+</div>
                    <div class="stat-label">Deployments Processed</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number">24/7</div>
                    <div class="stat-label">Expert Support</div>
                </div>
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="footer">
        <div class="footer-content">
            <p class="footer-text">
                Built with ❤️ for modern development teams. 
                Experience the future of CI/CD today.
            </p>
            <div class="footer-links">
                <a href="/" class="footer-link">Dashboard</a>
                <a href="/health" class="footer-link">Health Check</a>
                <a href="/api" class="footer-link">API Docs</a>
                <a href="/cleanup" class="footer-link">System Status</a>
            </div>
            <p style="color: var(--text-muted); font-size: 14px;">
                © 2025 NextGen CI/CD Platform. All rights reserved.
            </p>
        </div>
    </footer>

    <script>
        // Smooth scrolling and navbar effects
        document.addEventListener('DOMContentLoaded', function() {
            const navbar = document.getElementById('navbar');
            
            // Navbar scroll effect
            window.addEventListener('scroll', function() {
                if (window.scrollY > 50) {
                    navbar.classList.add('scrolled');
                } else {
                    navbar.classList.remove('scrolled');
                }
            });

            // Smooth scrolling for anchor links
            document.querySelectorAll('a[href^="#"]').forEach(anchor => {
                anchor.addEventListener('click', function (e) {
                    e.preventDefault();
                    const target = document.querySelector(this.getAttribute('href'));
                    if (target) {
                        target.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }
                });
            });

            // Animate stats on scroll
            const observerOptions = {
                threshold: 0.5,
                rootMargin: '0px 0px -100px 0px'
            };

            const observer = new IntersectionObserver(function(entries) {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        const statNumbers = entry.target.querySelectorAll('.stat-number');
                        statNumbers.forEach(stat => {
                            const finalValue = stat.textContent;
                            if (!stat.classList.contains('animated')) {
                                stat.classList.add('animated');
                                if (finalValue.includes('%') || finalValue.includes('ms') || finalValue.includes('/')) {
                                    // For percentage, time, or ratio values
                                    stat.style.opacity = '0';
                                    setTimeout(() => {
                                        stat.style.opacity = '1';
                                        stat.style.transform = 'scale(1.1)';
                                        setTimeout(() => {
                                            stat.style.transform = 'scale(1)';
                                        }, 200);
                                    }, 100);
                                } else if (finalValue.includes('M+')) {
                                    // For large numbers
                                    let current = 0;
                                    const target = 10;
                                    const increment = target / 50;
                                    const timer = setInterval(() => {
                                        current += increment;
                                        if (current >= target) {
                                            stat.textContent = '10M+';
                                            clearInterval(timer);
                                        } else {
                                            stat.textContent = Math.floor(current) + 'M+';
                                        }
                                    }, 30);
                                }
                            }
                        });
                    }
                });
            }, observerOptions);

            const statsSection = document.querySelector('.stats');
            if (statsSection) {
                observer.observe(statsSection);
            }
        });
    </script>
</body>
</html>
  `;

  res.send(content);
});

// Only start server when not in test environment
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
    console.log('Deployment ID: 20250811_memory_optimized');
  });
}

module.exports = app;