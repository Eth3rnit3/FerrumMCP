# Use Ruby 3.2 with Alpine for smaller image size
# Force AMD64 platform for M1/M2/M3 Mac compatibility with Chrome
FROM --platform=linux/amd64 ruby:3.2-alpine

# Install Chrome and dependencies
RUN apk add --no-cache \
    chromium \
    chromium-chromedriver \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    git \
    build-base \
    wget \
    xvfb \
    xvfb-run

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
RUN bundle install --without development test

# Copy application code
COPY . .

# Expose the server port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Security options for Chrome
# Run with: docker run --security-opt seccomp=unconfined
# or add --cap-add=SYS_ADMIN if needed

# Run the server
CMD ["ruby", "server.rb"]
