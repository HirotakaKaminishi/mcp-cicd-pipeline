import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import Dashboard from './pages/Dashboard';
import Health from './pages/Health';
import ServiceLanding from './pages/ServiceLanding';
import './App.css';

function App() {
  return (
    <Router basename="/">
      <div className="app">
        <nav className="main-nav">
          <div className="nav-brand">
            <span className="brand-logo">MCP</span>
            <span className="brand-name">Monitoring Platform</span>
          </div>
          <div className="nav-links">
            <Link to="/" className="nav-item">Dashboard</Link>
            <Link to="/health" className="nav-item">Health Check</Link>
            <Link to="/service" className="nav-item">Service</Link>
          </div>
        </nav>

        <main className="main-content">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/health" element={<Health />} />
            <Route path="/service" element={<ServiceLanding />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App
