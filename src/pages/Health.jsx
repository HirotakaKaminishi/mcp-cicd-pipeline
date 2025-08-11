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
    }
  });

  useEffect(() => {
    const checkHealth = async () => {
      try {
        const response = await fetch('/api/health');
        const data = await response.json();
        setHealthData(data);
      } catch (error) {
        console.error('Health check failed:', error);
        setHealthData(prev => ({ ...prev, status: 'error' }));
      }
    };

    checkHealth();
    const interval = setInterval(checkHealth, 10000);
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
            <span className="metric-value">{healthData.metrics.uptime}%</span>
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
      </div>

      <div className="auto-refresh-notice">
        <svg className="refresh-icon" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" />
        </svg>
        Auto-refresh: Every 10 seconds
      </div>
    </div>
  );
}

export default Health;