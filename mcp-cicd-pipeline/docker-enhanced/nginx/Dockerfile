FROM nginx:alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Create directories with proper permissions
RUN mkdir -p /var/log/nginx /usr/share/nginx/html /var/cache/nginx /tmp \
    && chmod -R 755 /var/log/nginx /usr/share/nginx/html /var/cache/nginx /tmp \
    && chown -R nginx:nginx /var/log/nginx /usr/share/nginx/html /var/cache/nginx /tmp

# Copy static content
COPY html/ /usr/share/nginx/html/

# Ensure writable permissions for nginx user
RUN chown -R nginx:nginx /usr/share/nginx/html

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]