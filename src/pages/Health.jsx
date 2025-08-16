import { useState, useEffect } from 'react';

function Health() {
  const [healthData, setHealthData] = useState({
    status: 'checking',
    deployment_id: '',
    timestamp: '',
    services: {
      app: 'unknown',
      database: 'unknown',
      cache: 'unknown'
    },
    metrics: {
      uptime: 0,
      requests_per_minute: 0,
      error_rate: 0
    },
    system: {
      node_version: '',
      platform: '',
      arch: '',
      memory_usage: {},
      cpu_count: 0
    }
  });

  const [mcpStatus, setMcpStatus] = useState({
    status: 'checking',
    system: '',
    connectivity: 'unknown'
  });

  const [nginxStatus, setNginxStatus] = useState({
    status: 'checking',
    version: '',
    features: []
  });

  useEffect(() => {
    const checkHealth = async () => {
      try {
        // API Health Check
        const response = await fetch('/api/health');
        const data = await response.json();
        setHealthData(data);

        // MCP Server Health Check
        try {
          const mcpResponse = await fetch('http://192.168.111.200:8080', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              jsonrpc: '2.0',
              method: 'get_system_info',
              id: 1
            })
          });
          const mcpData = await mcpResponse.json();
          setMcpStatus({
            status: 'operational',
            system: mcpData.result?.system || 'Unknown',
            connectivity: 'connected'
          });
        } catch (mcpError) {
          console.error('MCP health check failed:', mcpError);
          setMcpStatus(prev => ({ ...prev, status: 'error', connectivity: 'disconnected' }));
        }

        // nginx Health Check
        try {
          const nginxResponse = await fetch('/health');
          if (nginxResponse.ok) {
            setNginxStatus({
              status: 'operational',
              version: '1.29.0',
              features: ['security-headers', 'compression', 'caching', 'optimization']
            });
          }
        } catch (nginxError) {
          console.error('nginx health check failed:', nginxError);
          setNginxStatus(prev => ({ ...prev, status: 'error' }));
        }

      } catch (error) {
        console.error('Health check failed:', error);
        setHealthData(prev => ({ ...prev, status: 'error' }));
      }
    };

    checkHealth();
    const interval = setInterval(checkHealth, 15000);
    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy':
      case 'operational':
        return '#00e396';
      case 'degraded':
        return '#feb019';
      case 'error':
      case 'down':
        return '#ff4560';
      default:
        return '#999';
    }
  };

  return (
    <div className="health-check">
      <div className="dashboard-header">
        <h1>System Health Check</h1>
        <div className="status-badge" style={{ backgroundColor: getStatusColor(healthData.status) }}>
          <span className="status-dot"></span>
          {healthData.status}
        </div>
      </div>

      <div className="info-grid">
        <div className="info-card">
          <h3>Deployment Info</h3>
          <div className="info-item">
            <span className="info-label">Deployment ID:</span>
            <span className="info-value">{healthData.deployment_id || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Last Updated:</span>
            <span className="info-value">{healthData.timestamp || 'N/A'}</span>
          </div>
        </div>

        <div className="info-card">
          <h3>Services Status</h3>
          {Object.entries(healthData.services).map(([service, status]) => (
            <div key={service} className="service-item">
              <span className="service-name">{service}:</span>
              <span 
                className="service-status" 
                style={{ color: getStatusColor(status) }}
              >
                {status}
              </span>
            </div>
          ))}
        </div>

        <div className="info-card">
          <h3>Metrics</h3>
          <div className="metric-item">
            <span className="metric-label">Uptime:</span>
            <span className="metric-value">{healthData.metrics.uptime}</span>
          </div>
          <div className="metric-item">
            <span className="metric-label">Requests/min:</span>
            <span className="metric-value">{healthData.metrics.requests_per_minute}</span>
          </div>
          <div className="metric-item">
            <span className="metric-label">Error Rate:</span>
            <span className="metric-value">{healthData.metrics.error_rate}%</span>
          </div>
        </div>

        <div className="info-card">
          <h3>System Information</h3>
          <div className="info-item">
            <span className="info-label">Node.js:</span>
            <span className="info-value">{healthData.system.node_version || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Platform:</span>
            <span className="info-value">{healthData.system.platform || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Architecture:</span>
            <span className="info-value">{healthData.system.arch || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="info-label">CPU Cores:</span>
            <span className="info-value">{healthData.system.cpu_count || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Memory Usage:</span>
            <span className="info-value">
              {healthData.system.memory_usage?.heapUsed && healthData.system.memory_usage?.heapTotal 
                ? `${Math.round(healthData.system.memory_usage.heapUsed / 1024 / 1024)}MB / ${Math.round(healthData.system.memory_usage.heapTotal / 1024 / 1024)}MB`
                : 'N/A'
              }
            </span>
          </div>
        </div>

        <div className="info-card">
          <h3>MCP Server Status</h3>
          <div className="service-item">
            <span className="service-name">Status:</span>
            <span 
              className="service-status" 
              style={{ color: getStatusColor(mcpStatus.status) }}
            >
              {mcpStatus.status}
            </span>
          </div>
          <div className="service-item">
            <span className="service-name">Connectivity:</span>
            <span 
              className="service-status" 
              style={{ color: getStatusColor(mcpStatus.connectivity === 'connected' ? 'operational' : 'error') }}
            >
              {mcpStatus.connectivity}
            </span>
          </div>
          <div className="info-item">
            <span className="info-label">System:</span>
            <span className="info-value">{mcpStatus.system || 'N/A'}</span>
          </div>
        </div>

        <div className="info-card">
          <h3>nginx Status</h3>
          <div className="service-item">
            <span className="service-name">Status:</span>
            <span 
              className="service-status" 
              style={{ color: getStatusColor(nginxStatus.status) }}
            >
              {nginxStatus.status}
            </span>
          </div>
          <div className="info-item">
            <span className="info-label">Version:</span>
            <span className="info-value">{nginxStatus.version || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="info-label">Features:</span>
            <span className="info-value">
              {nginxStatus.features.length > 0 
                ? nginxStatus.features.join(', ')
                : 'N/A'
              }
            </span>
          </div>
        </div>
      </div>

      <div className="auto-refresh-notice">
        <svg className="refresh-icon" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" />
        </svg>
        Auto-refresh: Every 15 seconds
      </div>
    </div>
  );
}

export default Health;