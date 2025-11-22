# Use Ruby 3.2 with Alpine for smaller image size
# Supports both AMD64 and ARM64 platforms
FROM ruby:3.2-alpine

# Install runtime dependencies and build dependencies
RUN apk add --no-cache \
    # Runtime: Browser and core dependencies
    chromium \
    chromium-chromedriver \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    wget \
    xvfb \
    xvfb-run \
    # Runtime: libvips for ruby-vips gem
    vips \
    && \
    # Build dependencies (will be removed after bundle install)
    apk add --no-cache --virtual .build-deps \
    build-base \
    vips-dev

# Create non-root user
RUN addgroup -g 1000 ferrum && \
    adduser -D -u 1000 -G ferrum ferrum

# Set Chrome path for Ferrum
ENV BROWSER_PATH=/usr/bin/chromium-browser \
    BROWSER_HEADLESS=true \
    DOCKER=true \
    PORT=3000 \
    HOST=0.0.0.0 \
    LOG_LEVEL=info \
    BROWSER_TIMEOUT=120

# Create app directory
WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install --jobs=4 --retry=3 && \
    # Remove build dependencies to reduce image size
    apk del .build-deps && \
    # Clean bundle cache
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -name "*.c" -delete && \
    find /usr/local/bundle/gems/ -name "*.o" -delete

# Copy application code (only what's needed)
COPY --chown=ferrum:ferrum lib ./lib
COPY --chown=ferrum:ferrum bin ./bin
COPY --chown=ferrum:ferrum config ./config

# Create logs directory and set proper permissions
RUN mkdir -p logs tmp && \
    chown -R ferrum:ferrum /app

# Switch to non-root user
USER ferrum

# Expose the server port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Security options for Chrome
# Run with: docker run --security-opt seccomp=unconfined
# or add --cap-add=SYS_ADMIN if needed

# Run the server
CMD ["bin/ferrum-mcp", "start"]
