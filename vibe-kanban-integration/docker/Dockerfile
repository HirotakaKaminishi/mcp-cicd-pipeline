# Vibe-Kanban Dockerfile (Security Optimized)
# Based on the BestPractices from the analysis report

FROM node:18-alpine

# Security: Create non-root user
RUN addgroup -g 1001 -S vibekanban && \
    adduser -S vibe -u 1001 -G vibekanban

# Install system dependencies
RUN apk add --no-cache curl git

# Set working directory
WORKDIR /app

# Copy package files first (for better caching)
COPY package*.json ./

# Install dependencies as root, then change ownership
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Change ownership to non-root user
RUN chown -R vibe:vibekanban /app

# Switch to non-root user
USER vibe

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start command
CMD ["npm", "start"]