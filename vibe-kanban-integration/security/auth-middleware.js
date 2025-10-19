/**
 * Authentication and Authorization Middleware for Vibe-Kanban
 * Implements security best practices from the analysis report
 */

const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const crypto = require('crypto');

class SecurityMiddleware {
  constructor(options = {}) {
    this.jwtSecret = options.jwtSecret || process.env.JWT_SECRET || this.generateSecret();
    this.sessionSecret = options.sessionSecret || process.env.SESSION_SECRET || this.generateSecret();
    this.enableRateLimit = options.enableRateLimit !== false;
    this.enableCSRF = options.enableCSRF !== false;
    this.enterpriseMode = options.enterpriseMode || process.env.ENTERPRISE_MODE === 'true';
  }

  generateSecret() {
    return crypto.randomBytes(64).toString('hex');
  }

  // Rate limiting configuration
  createRateLimiter(windowMs = 15 * 60 * 1000, max = 100) {
    return rateLimit({
      windowMs,
      max,
      message: {
        error: 'Too many requests',
        message: 'Please try again later',
        retryAfter: Math.ceil(windowMs / 1000)
      },
      standardHeaders: true,
      legacyHeaders: false,
      handler: (req, res) => {
        console.warn(`Rate limit exceeded for IP: ${req.ip}, Path: ${req.path}`);
        res.status(429).json({
          error: 'Rate limit exceeded',
          message: 'Too many requests, please try again later'
        });
      }
    });
  }

  // Helmet security configuration
  helmetConfig() {
    return helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
          fontSrc: ["'self'", "https://fonts.gstatic.com"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: [
            "'self'",
            process.env.MCP_SERVER_URL || "http://mcp-server:8080",
            "https://api.github.com"
          ],
          frameSrc: ["'none'"],
          objectSrc: ["'none'"]
        }
      },
      crossOriginEmbedderPolicy: false,
      hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
      }
    });
  }

  // JWT Token validation
  validateToken(req, res, next) {
    const token = req.headers.authorization?.split(' ')[1] || req.cookies?.token;

    if (!token) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'No token provided'
      });
    }

    try {
      const decoded = jwt.verify(token, this.jwtSecret);
      req.user = decoded;
      next();
    } catch (error) {
      console.warn(`Invalid token from IP: ${req.ip}`, { error: error.message });
      return res.status(401).json({
        error: 'Invalid token',
        message: 'Authentication failed'
      });
    }
  }

  // Role-based access control
  requireRole(roles) {
    return (req, res, next) => {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          message: 'User not authenticated'
        });
      }

      const userRoles = Array.isArray(req.user.roles) ? req.user.roles : [req.user.role];
      const requiredRoles = Array.isArray(roles) ? roles : [roles];
      
      const hasPermission = requiredRoles.some(role => userRoles.includes(role));

      if (!hasPermission) {
        console.warn(`Access denied for user: ${req.user.id}, required roles: ${requiredRoles.join(', ')}`);
        return res.status(403).json({
          error: 'Access denied',
          message: 'Insufficient permissions'
        });
      }

      next();
    };
  }

  // AI Agent protection middleware
  protectCriticalPaths() {
    const criticalPaths = [
      '/api/kanban/admin',
      '/api/kanban/config',
      '/api/kanban/security',
      '/api/system'
    ];

    return (req, res, next) => {
      const isCriticalPath = criticalPaths.some(path => req.path.startsWith(path));
      
      if (isCriticalPath) {
        // Require human authorization for critical operations
        if (req.headers['x-agent-type'] && !req.headers['x-human-approved']) {
          return res.status(403).json({
            error: 'Human approval required',
            message: 'This operation requires human authorization',
            requiredHeaders: {
              'x-human-approved': 'true',
              'x-human-approver': 'username'
            }
          });
        }

        // Log all critical path access
        console.info('Critical path access:', {
          path: req.path,
          method: req.method,
          user: req.user?.id || 'anonymous',
          agent: req.headers['x-agent-type'],
          ip: req.ip,
          timestamp: new Date().toISOString()
        });
      }

      next();
    };
  }

  // Agent concurrency limiter
  createAgentLimiter() {
    const activeAgents = new Map();
    const maxConcurrentAgents = parseInt(process.env.AI_AGENT_CONCURRENCY_LIMIT) || 3;

    return (req, res, next) => {
      const agentType = req.headers['x-agent-type'];
      
      if (agentType) {
        const currentTime = Date.now();
        const activeCount = Array.from(activeAgents.values())
          .filter(timestamp => currentTime - timestamp < 30000) // 30 second window
          .length;

        if (activeCount >= maxConcurrentAgents) {
          return res.status(429).json({
            error: 'Agent limit exceeded',
            message: `Maximum ${maxConcurrentAgents} concurrent AI agents allowed`,
            currentActive: activeCount
          });
        }

        // Register this agent request
        const requestId = req.headers['x-request-id'] || crypto.randomUUID();
        activeAgents.set(requestId, currentTime);

        // Cleanup old entries
        setTimeout(() => activeAgents.delete(requestId), 30000);
      }

      next();
    };
  }

  // GitHub webhook signature validation
  validateGitHubWebhook() {
    return (req, res, next) => {
      const signature = req.headers['x-hub-signature-256'];
      const payload = JSON.stringify(req.body);
      const secret = process.env.GITHUB_WEBHOOK_SECRET;

      if (!secret || !signature) {
        return res.status(401).json({
          error: 'Webhook validation failed',
          message: 'Missing signature or secret'
        });
      }

      const expectedSignature = `sha256=${crypto
        .createHmac('sha256', secret)
        .update(payload)
        .digest('hex')}`;

      if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature))) {
        console.warn('GitHub webhook signature validation failed', {
          ip: req.ip,
          timestamp: new Date().toISOString()
        });
        return res.status(401).json({
          error: 'Webhook validation failed',
          message: 'Invalid signature'
        });
      }

      next();
    };
  }

  // Request logging and monitoring
  securityLogger() {
    return (req, res, next) => {
      const startTime = Date.now();

      // Log security-relevant information
      const securityLog = {
        timestamp: new Date().toISOString(),
        method: req.method,
        path: req.path,
        ip: req.ip,
        userAgent: req.headers['user-agent'],
        agentType: req.headers['x-agent-type'],
        userId: req.user?.id,
        contentLength: req.headers['content-length']
      };

      // Log suspicious patterns
      const suspiciousPatterns = [
        /\.\.\//,  // Directory traversal
        /<script/i,  // XSS attempts
        /union.*select/i,  // SQL injection
        /javascript:/i  // JavaScript protocol
      ];

      const requestString = `${req.path} ${JSON.stringify(req.query)} ${req.body ? JSON.stringify(req.body) : ''}`;
      const isSuspicious = suspiciousPatterns.some(pattern => pattern.test(requestString));

      if (isSuspicious) {
        console.warn('Suspicious request detected:', {
          ...securityLog,
          suspiciousContent: requestString
        });
      }

      res.on('finish', () => {
        const responseTime = Date.now() - startTime;
        console.log('Request completed:', {
          ...securityLog,
          statusCode: res.statusCode,
          responseTime: `${responseTime}ms`
        });
      });

      next();
    };
  }

  // Enterprise security mode
  enterpriseSecurityMode() {
    return (req, res, next) => {
      if (this.enterpriseMode) {
        // Additional enterprise security checks
        req.headers['x-enterprise-mode'] = 'true';
        
        // Require stronger authentication
        if (req.headers['x-agent-type'] && !req.headers['x-enterprise-token']) {
          return res.status(403).json({
            error: 'Enterprise mode active',
            message: 'Additional enterprise authentication required'
          });
        }
      }
      
      next();
    };
  }
}

module.exports = SecurityMiddleware;