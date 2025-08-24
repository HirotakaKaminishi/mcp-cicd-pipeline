# Vibe-Kanban Production-Ready Container
# PRODUCTION SOLUTION: NPM Global Package Installation
# Uses pre-built npm package to avoid development dependencies

FROM node:20-bullseye-slim

# Install runtime dependencies for vibe-kanban
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    chromium \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxss1 \
    libgconf-2-4 \
    libxrandr2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libgbm1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Create non-root user for security best practices
RUN groupadd -g 1001 vibekanban && \
    useradd -r -s /bin/bash -g vibekanban -u 1001 vibe -m

# Install vibe-kanban globally from npm
RUN npm install -g vibe-kanban

# Set working directory
WORKDIR /app

# Create necessary directories with proper permissions
RUN mkdir -p /app/data /app/logs /app/.config /app/.npm && \
    chown -R vibe:vibekanban /app /home/vibe

# Switch to non-root user
USER vibe

# Set npm cache directory for the vibe user
ENV NPM_CONFIG_CACHE=/app/.npm

# Set environment variables
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000

# Expose port
EXPOSE 3000

# Health check with appropriate timeout
HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Start vibe-kanban using globally installed package
CMD ["sh", "-c", "echo 'Starting vibe-kanban from npm package...' && \
    echo 'Node.js version:' && node --version && \
    echo 'npm version:' && npm --version && \
    echo 'Starting vibe-kanban server...' && \
    vibe-kanban --host=0.0.0.0 --port=3000"]