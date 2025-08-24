# Vibe-Kanban Complete Docker Container
# This integrates vibe-kanban directly into the Docker environment

FROM node:20-alpine

# Install system dependencies
RUN apk add --no-cache \
    curl \
    git \
    python3 \
    make \
    g++ \
    bash \
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Set Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Create non-root user
RUN addgroup -g 1001 -S vibekanban && \
    adduser -S vibe -u 1001 -G vibekanban

# Set working directory
WORKDIR /app

# Install vibe-kanban globally as root
RUN npm install -g vibe-kanban@latest

# Create necessary directories with proper permissions
RUN mkdir -p /app/data /app/logs /app/.config /app/.npm && \
    chown -R vibe:vibekanban /app /home/vibe

# Switch to non-root user
USER vibe

# Set npm cache directory for the vibe user
ENV NPM_CONFIG_CACHE=/app/.npm

# Expose vibe-kanban port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=15s --timeout=5s --start-period=45s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Start vibe-kanban with proper configuration
CMD ["npx", "vibe-kanban", "--port", "3000", "--host", "0.0.0.0"]