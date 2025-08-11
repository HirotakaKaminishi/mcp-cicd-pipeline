import { useEffect } from 'react';
import './ServiceLanding.css';

function ServiceLanding() {
  useEffect(() => {
    // Smooth scroll for navigation
    const handleScroll = (e) => {
      e.preventDefault();
      const targetId = e.target.getAttribute('href').substring(1);
      const targetElement = document.getElementById(targetId);
      if (targetElement) {
        targetElement.scrollIntoView({ behavior: 'smooth' });
      }
    };

    const links = document.querySelectorAll('a[href^="#"]');
    links.forEach(link => link.addEventListener('click', handleScroll));

    return () => {
      links.forEach(link => link.removeEventListener('click', handleScroll));
    };
  }, []);

  return (
    <div className="service-landing">
      <div className="animated-bg">
        <div className="gradient-orb orb-1"></div>
        <div className="gradient-orb orb-2"></div>
        <div className="gradient-orb orb-3"></div>
      </div>

      <nav className="nav-modern">
        <div className="nav-container">
          <div className="nav-brand">
            <div className="brand-icon">CI</div>
            <span className="brand-text">NextGen Platform</span>
          </div>
          <div className="nav-menu">
            <a href="#features" className="nav-link">Features</a>
            <a href="#stats" className="nav-link">Statistics</a>
            <a href="#testimonials" className="nav-link">Reviews</a>
            <a href="#contact" className="nav-link nav-cta">Get Started</a>
          </div>
        </div>
      </nav>

      <section className="hero-section">
        <div className="hero-content">
          <div className="hero-badge">
            <span className="badge-icon">🚀</span>
            <span>Deploy with Confidence</span>
          </div>
          <h1 className="hero-title">
            NextGen CI/CD
            <span className="gradient-text">Platform</span>
          </h1>
          <p className="hero-subtitle">
            Revolutionary CI/CD platform that transforms your deployment workflow
            with zero-downtime updates and real-time monitoring
          </p>
          <div className="hero-actions">
            <button className="btn-primary">
              <span>Start Free Trial</span>
              <svg className="btn-icon" viewBox="0 0 20 20" fill="currentColor">
                <path d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" />
              </svg>
            </button>
            <button className="btn-secondary">
              <svg className="btn-icon" viewBox="0 0 20 20" fill="currentColor">
                <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                <path fillRule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
              <span>Watch Demo</span>
            </button>
          </div>
        </div>
        <div className="hero-visual">
          <div className="floating-card card-1">
            <div className="card-icon">📊</div>
            <div className="card-label">Real-time Analytics</div>
          </div>
          <div className="floating-card card-2">
            <div className="card-icon">🔄</div>
            <div className="card-label">Auto Scaling</div>
          </div>
          <div className="floating-card card-3">
            <div className="card-icon">🛡️</div>
            <div className="card-label">Security First</div>
          </div>
        </div>
      </section>

      <section id="features" className="features-section">
        <div className="section-container">
          <h2 className="section-title">Powerful Features</h2>
          <div className="features-grid">
            <div className="feature-card">
              <div className="feature-icon-wrapper">
                <div className="feature-icon">🚀</div>
              </div>
              <h3>Zero-Downtime Deployments</h3>
              <p>Seamless blue-green deployments with automatic rollback capabilities</p>
              <div className="feature-stats">
                <div className="stat">
                  <span className="stat-value">99.99%</span>
                  <span className="stat-label">Uptime</span>
                </div>
                <div className="stat">
                  <span className="stat-value">&lt;1s</span>
                  <span className="stat-label">Switch Time</span>
                </div>
              </div>
            </div>

            <div className="feature-card">
              <div className="feature-icon-wrapper">
                <div className="feature-icon">📊</div>
              </div>
              <h3>Real-Time Monitoring</h3>
              <p>Advanced metrics and logging with AI-powered anomaly detection</p>
              <div className="feature-stats">
                <div className="stat">
                  <span className="stat-value">24/7</span>
                  <span className="stat-label">Monitoring</span>
                </div>
                <div className="stat">
                  <span className="stat-value">100ms</span>
                  <span className="stat-label">Alert Time</span>
                </div>
              </div>
            </div>

            <div className="feature-card">
              <div className="feature-icon-wrapper">
                <div className="feature-icon">🔒</div>
              </div>
              <h3>Enterprise Security</h3>
              <p>SOC2 compliant with end-to-end encryption and audit logs</p>
              <div className="feature-stats">
                <div className="stat">
                  <span className="stat-value">256-bit</span>
                  <span className="stat-label">Encryption</span>
                </div>
                <div className="stat">
                  <span className="stat-value">SOC2</span>
                  <span className="stat-label">Certified</span>
                </div>
              </div>
            </div>

            <div className="feature-card">
              <div className="feature-icon-wrapper">
                <div className="feature-icon">⚡</div>
              </div>
              <h3>Lightning Fast</h3>
              <p>Optimized build times with intelligent caching and parallelization</p>
              <div className="feature-stats">
                <div className="stat">
                  <span className="stat-value">10x</span>
                  <span className="stat-label">Faster</span>
                </div>
                <div className="stat">
                  <span className="stat-value">90%</span>
                  <span className="stat-label">Cache Hit</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="stats" className="stats-section">
        <div className="section-container">
          <h2 className="section-title">Trusted by Developers Worldwide</h2>
          <div className="stats-grid">
            <div className="stat-card">
              <div className="stat-number">10M+</div>
              <div className="stat-description">Deployments</div>
            </div>
            <div className="stat-card">
              <div className="stat-number">50K+</div>
              <div className="stat-description">Active Users</div>
            </div>
            <div className="stat-card">
              <div className="stat-number">99.99%</div>
              <div className="stat-description">Uptime SLA</div>
            </div>
            <div className="stat-card">
              <div className="stat-number">150+</div>
              <div className="stat-description">Countries</div>
            </div>
          </div>
        </div>
      </section>

      <footer className="footer-modern">
        <div className="footer-content">
          <p>&copy; 2025 NextGen CI/CD Platform. All rights reserved.</p>
          <div className="footer-links">
            <a href="#privacy">Privacy</a>
            <a href="#terms">Terms</a>
            <a href="#contact">Contact</a>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default ServiceLanding;