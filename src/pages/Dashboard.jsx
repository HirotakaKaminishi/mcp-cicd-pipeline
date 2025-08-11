import { useState, useEffect } from 'react';
import { Line, Doughnut } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  TimeScale
} from 'chart.js';
import 'chartjs-adapter-date-fns';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  TimeScale
);

function Dashboard() {
  const [systemData, setSystemData] = useState({
    app: { cpu: 0, memory: 0 },
    server: { cpu: 0, memory: 0 },
    containers: []
  });
  const [resourceHistory, setResourceHistory] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        // Fetch system data
        const sysResponse = await fetch('/api/system');
        const sysData = await sysResponse.json();
        
        // Fetch resource history
        const histResponse = await fetch('/api/resources/history');
        const histData = await histResponse.json();
        
        setSystemData({
          app: {
            cpu: sysData.app?.cpu?.usage_percent || 0,
            memory: sysData.app?.memory?.heap_usage_percent || 0
          },
          server: {
            cpu: sysData.system?.cpu?.usage || 0,
            memory: sysData.system?.memory?.used_percent || 0
          },
          containers: sysData.containers || []
        });
        
        setResourceHistory(histData.data || []);
      } catch (error) {
        console.error('Failed to fetch data:', error);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 10000);
    return () => clearInterval(interval);
  }, []);

  const createGaugeData = (value, label, color) => ({
    datasets: [{
      data: [value, 100 - value],
      backgroundColor: [color, '#2a2d32'],
      borderWidth: 0
    }],
    labels: [label]
  });

  const gaugeOptions = {
    responsive: true,
    maintainAspectRatio: false,
    circumference: 180,
    rotation: 270,
    cutout: '75%',
    plugins: {
      legend: { display: false },
      tooltip: { enabled: false }
    }
  };

  const lineChartData = {
    labels: resourceHistory.map(d => new Date(d.timestamp)),
    datasets: [
      {
        label: 'CPU %',
        data: resourceHistory.map(d => d.cpu.usage_percent),
        borderColor: '#00e396',
        backgroundColor: 'rgba(0, 227, 150, 0.1)',
        tension: 0.4
      },
      {
        label: 'Memory %',
        data: resourceHistory.map(d => d.memory.heap_usage_percent),
        borderColor: '#feb019',
        backgroundColor: 'rgba(254, 176, 25, 0.1)',
        tension: 0.4
      }
    ]
  };

  const lineChartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        labels: { color: '#d9d9d9' }
      }
    },
    scales: {
      x: {
        type: 'time',
        grid: { color: '#2a2d32' },
        ticks: { color: '#999' }
      },
      y: {
        min: 0,
        max: 100,
        grid: { color: '#2a2d32' },
        ticks: { color: '#999' }
      }
    }
  };

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1>System Monitoring Dashboard</h1>
        <div className="status-badge">
          <span className="status-dot"></span>
          Production
        </div>
      </div>

      <div className="gauge-grid">
        <div className="gauge-card">
          <h3>App Memory</h3>
          <div className="gauge-container">
            <Doughnut data={createGaugeData(systemData.app.memory, 'Memory', '#feb019')} options={gaugeOptions} />
            <div className="gauge-value">{systemData.app.memory.toFixed(1)}%</div>
          </div>
        </div>

        <div className="gauge-card">
          <h3>App CPU</h3>
          <div className="gauge-container">
            <Doughnut data={createGaugeData(systemData.app.cpu, 'CPU', '#00e396')} options={gaugeOptions} />
            <div className="gauge-value">{systemData.app.cpu.toFixed(1)}%</div>
          </div>
        </div>

        <div className="gauge-card">
          <h3>Server Memory</h3>
          <div className="gauge-container">
            <Doughnut data={createGaugeData(systemData.server.memory, 'Memory', '#775dd0')} options={gaugeOptions} />
            <div className="gauge-value">{systemData.server.memory.toFixed(1)}%</div>
          </div>
        </div>

        <div className="gauge-card">
          <h3>Server CPU</h3>
          <div className="gauge-container">
            <Doughnut data={createGaugeData(systemData.server.cpu, 'CPU', '#008ffb')} options={gaugeOptions} />
            <div className="gauge-value">{systemData.server.cpu.toFixed(1)}%</div>
          </div>
        </div>
      </div>

      <div className="chart-card">
        <h3>Resource History</h3>
        <div className="chart-container">
          <Line data={lineChartData} options={lineChartOptions} />
        </div>
      </div>

      {systemData.containers.length > 0 && (
        <div className="containers-card">
          <h3>Docker Containers</h3>
          <div className="container-list">
            {systemData.containers.map((container, idx) => (
              <div key={idx} className="container-item">
                <span className="container-name">{container.name}</span>
                <span className={`container-status ${container.state}`}>{container.state}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default Dashboard;