# Docker Deployment Guide

This guide covers deploying FerrumMCP using Docker, including integration with Claude Desktop and Claude Code.

## Table of Contents

- [Quick Start](#quick-start)
- [Docker Images](#docker-images)
- [Running the Container](#running-the-container)
- [BotBrowser Integration](#botbrowser-integration)
- [Claude Desktop Integration](#claude-desktop-integration)
- [Claude Code Integration](#claude-code-integration)
- [Environment Variables](#environment-variables)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Standard Image (Chromium Only)

```bash
docker pull eth3rnit3/ferrum-mcp:latest
docker run -d -p 3000:3000 --security-opt seccomp=unconfined eth3rnit3/ferrum-mcp:latest
```

### BotBrowser Image (Anti-Detection)

```bash
docker pull eth3rnit3/ferrum-mcp:botbrowser
docker run -d -p 3000:3000 --security-opt seccomp=unconfined \
  -v ./profiles:/app/profiles:ro \
  eth3rnit3/ferrum-mcp:botbrowser
```

### Build Locally

```bash
git clone https://github.com/Eth3rnit3/FerrumMCP.git
cd FerrumMCP

# Standard image
docker build -t ferrum-mcp:latest .

# BotBrowser image
docker build -f Dockerfile.with-botbrowser --build-arg INCLUDE_BOTBROWSER=true \
  -t ferrum-mcp:botbrowser .
```

The server will be available at `http://localhost:3000`.

---

## Docker Images

We provide **two Docker images** on Docker Hub:

### 1. Standard Image (`latest`)

- **Tag**: `eth3rnit3/ferrum-mcp:latest`
- **Base**: `ruby:3.2-alpine`
- **Size**: ~1.84GB
- **Browser**: Chromium (headless only)
- **Use case**: General browser automation

**Image details:**
- User: `ferrum` (non-root, UID 1000)
- Platforms: `linux/amd64`, `linux/arm64`
- Health check included
- Automatic cleanup of build dependencies

### 2. BotBrowser Image (`botbrowser`)

- **Tag**: `eth3rnit3/ferrum-mcp:botbrowser`
- **Base**: `ruby:3.2-alpine`
- **Size**: ~4.14GB
- **Browsers**: Chromium + BotBrowser (257.8MB)
- **Use case**: Anti-detection automation, fingerprint management

**Features:**
- Automatic BotBrowser download from GitHub releases
- Multi-architecture support (amd64/arm64)
- Profile encryption support
- Advanced anti-detection capabilities

### What's Included

✅ **Runtime Dependencies**
- Chromium browser
- ChromeDriver
- libvips (for image processing)
- Required fonts and libraries

✅ **Security Features**
- Non-root user execution
- Minimal attack surface
- Build dependencies removed after installation

✅ **Optimizations**
- Multi-stage build process
- Bundle cache cleaned (~30MB saved)
- Only essential files copied

### Image Layers

```dockerfile
FROM ruby:3.2-alpine
├── Install runtime dependencies (chromium, vips)
├── Install build dependencies (removed after)
├── Create non-root user (ferrum)
├── Bundle install & cleanup
├── Copy application code
└── Switch to non-root user
```

---

## Running the Container

### HTTP Transport (Default)

For HTTP-based MCP clients:

```bash
docker run -d \
  --name ferrum-mcp \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  ferrum-mcp:latest
```

**Endpoints:**
- MCP: `http://localhost:3000/mcp`
- Health: `http://localhost:3000/health`

### STDIO Transport

For Claude Desktop or other STDIO-based clients:

```bash
docker run --rm -i \
  --security-opt seccomp=unconfined \
  ferrum-mcp:latest \
  ruby bin/ferrum-mcp --transport stdio
```

### With Environment Variables

```bash
docker run -d \
  --name ferrum-mcp \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  -e LOG_LEVEL=debug \
  -e BROWSER_TIMEOUT=90 \
  ferrum-mcp:latest
```

### Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  ferrum-mcp:
    image: ferrum-mcp:latest
    container_name: ferrum-mcp
    security_opt:
      - seccomp:unconfined
    ports:
      - "3000:3000"
    environment:
      - LOG_LEVEL=info
      - BROWSER_TIMEOUT=120
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
```

Run with:
```bash
docker-compose up -d
```

---

## BotBrowser Integration

The BotBrowser image (`eth3rnit3/ferrum-mcp:botbrowser`) includes anti-detection capabilities for bypassing bot detection systems.

### Downloading BotBrowser Profiles

BotBrowser profiles must be obtained separately (licensed). Download from [BotBrowser](https://botbrowser.com).

**Profile types:**
- **Operating Systems**: macOS, Windows, Linux, Android
- **Browsers**: Chrome, Firefox, Edge, Safari
- **Formats**: `.enc` (encrypted) or unencrypted

### Running with Bot Profiles

**1. Create profiles directory:**

```bash
mkdir -p ./profiles
# Copy your .enc profile files to ./profiles/
cp ~/Downloads/*.enc ./profiles/
```

**2. Run container with profiles mounted:**

```bash
docker run -d \
  --name ferrum-mcp-bot \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  -v "$(pwd)/profiles:/app/profiles:ro" \
  -e "BOT_PROFILE_US=/app/profiles/us_chrome.enc:US Chrome:Chrome US fingerprint" \
  -e "BOT_PROFILE_EU=/app/profiles/eu_firefox.enc:EU Firefox:Firefox EU fingerprint" \
  eth3rnit3/ferrum-mcp:botbrowser
```

**Profile environment variable format:**
```
BOT_PROFILE_<ID>=path:name:description
```

**3. Discover available profiles:**

Once the container is running, you can query available profiles via the MCP resource endpoint:

```bash
curl -X POST http://localhost:3000/mcp/v1 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "resources/read",
    "params": {
      "uri": "ferrum://bot-profiles"
    }
  }'
```

**4. Create session with BotBrowser profile:**

```bash
curl -X POST http://localhost:3000/mcp/v1 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "create_session",
      "arguments": {
        "bot_profile_id": "us",
        "headless": true
      }
    }
  }'
```

### Docker Compose with BotBrowser

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  ferrum-mcp-botbrowser:
    image: eth3rnit3/ferrum-mcp:botbrowser
    container_name: ferrum-mcp-bot
    security_opt:
      - seccomp:unconfined
    ports:
      - "3000:3000"
    volumes:
      - ./profiles:/app/profiles:ro
    environment:
      - LOG_LEVEL=info
      - BROWSER_TIMEOUT=120
      # BotBrowser profiles
      - BOT_PROFILE_US=/app/profiles/us_chrome.enc:US Chrome:Chrome US fingerprint
      - BOT_PROFILE_EU=/app/profiles/eu_firefox.enc:EU Firefox:Firefox EU fingerprint
      - BOT_PROFILE_ANDROID=/app/profiles/android.enc:Android:Mobile fingerprint
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
```

---

## Claude Desktop Integration

### Prerequisites

- Docker installed and running
- Claude Desktop installed
- FerrumMCP Docker image available

### Configuration

**Config file location:**
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

**Configuration:**

```json
{
  "mcpServers": {
    "ferrum-mcp": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "--security-opt",
        "seccomp=unconfined",
        "ferrum-mcp:latest",
        "ruby",
        "bin/ferrum-mcp",
        "--transport",
        "stdio"
      ],
      "env": {}
    }
  }
}
```

### How It Works

1. **Claude Desktop** starts the Docker container when needed
2. Container runs in **interactive mode** (`-i`)
3. Communication via **STDIO** (stdin/stdout)
4. Container is **automatically removed** (`--rm`) when Claude Desktop stops
5. **Headless mode enforced** (see security section below)

### After Configuration

1. **Save** the configuration file
2. **Restart** Claude Desktop
3. **Test** by asking Claude to navigate to a website

### Rebuilding After Code Changes

If you modify the FerrumMCP code:

```bash
# Rebuild the image
cd /path/to/ferrum-mcp
docker build -t ferrum-mcp:latest .

# Restart Claude Desktop
# The new image will be used on next launch
```

---

## Claude Code Integration

[Claude Code](https://claude.com/code) supports MCP servers via HTTP transport, making it perfect for Docker deployments.

### Standard Image Setup

**1. Start the container:**

```bash
docker run -d \
  --name ferrum-mcp \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  eth3rnit3/ferrum-mcp:latest
```

**2. Configure Claude Code:**

Add to your Claude Code MCP settings (`~/.config/claude-code/mcp-servers.json` or via settings UI):

```json
{
  "ferrum-mcp": {
    "url": "http://localhost:3000/mcp/v1",
    "transport": "http"
  }
}
```

**3. Verify connection:**

Ask Claude Code to test the connection:
```
Can you navigate to https://example.com and get the page title?
```

### BotBrowser Image Setup

For anti-detection automation with Claude Code:

**1. Prepare profiles directory:**

```bash
mkdir -p ~/ferrum-profiles
# Copy your BotBrowser .enc profiles
cp ~/Downloads/*.enc ~/ferrum-profiles/
```

**2. Start BotBrowser container:**

```bash
docker run -d \
  --name ferrum-mcp-bot \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  -v ~/ferrum-profiles:/app/profiles:ro \
  -e "BOT_PROFILE_US=/app/profiles/us_chrome.enc:US Chrome:US fingerprint" \
  -e "BOT_PROFILE_EU=/app/profiles/eu_firefox.enc:EU Firefox:EU fingerprint" \
  -e "BOT_PROFILE_MOBILE=/app/profiles/android.enc:Mobile:Android fingerprint" \
  eth3rnit3/ferrum-mcp:botbrowser
```

**3. Configure Claude Code** (same as standard setup):

```json
{
  "ferrum-mcp": {
    "url": "http://localhost:3000/mcp/v1",
    "transport": "http"
  }
}
```

**4. Use BotBrowser profiles with Claude Code:**

```
First, discover available BotBrowser profiles by reading the ferrum://bot-profiles resource.
Then create a session with bot_profile_id "us" and navigate to a protected website.
```

Claude Code will:
1. Query the `ferrum://bot-profiles` resource to see available profiles
2. Create a session with the specified profile
3. Perform browser automation with anti-detection enabled

### Docker Compose for Claude Code

Create `docker-compose.yml` for persistent setup:

```yaml
version: '3.8'

services:
  # Standard browser automation
  ferrum-mcp:
    image: eth3rnit3/ferrum-mcp:latest
    container_name: ferrum-mcp
    security_opt:
      - seccomp:unconfined
    ports:
      - "3000:3000"
    environment:
      - LOG_LEVEL=info
      - BROWSER_TIMEOUT=120
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 3s
      retries: 3

  # BotBrowser (anti-detection)
  ferrum-mcp-bot:
    image: eth3rnit3/ferrum-mcp:botbrowser
    container_name: ferrum-mcp-bot
    security_opt:
      - seccomp:unconfined
    ports:
      - "3001:3000"  # Different port to run alongside standard
    volumes:
      - ~/ferrum-profiles:/app/profiles:ro
    environment:
      - LOG_LEVEL=info
      - BROWSER_TIMEOUT=120
      - BOT_PROFILE_US=/app/profiles/us_chrome.enc:US:Chrome US
      - BOT_PROFILE_EU=/app/profiles/eu_chrome.enc:EU:Chrome EU
      - BOT_PROFILE_MOBILE=/app/profiles/android.enc:Mobile:Android
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
```

**Start both:**
```bash
docker-compose up -d
```

**Configure both in Claude Code:**
```json
{
  "ferrum-mcp-standard": {
    "url": "http://localhost:3000/mcp/v1",
    "transport": "http"
  },
  "ferrum-mcp-botbrowser": {
    "url": "http://localhost:3001/mcp/v1",
    "transport": "http"
  }
}
```

### Example Usage with Claude Code

**Discover resources:**
```
Read the ferrum://browsers resource to see what browsers are available.
Then read ferrum://bot-profiles to see BotBrowser profiles.
```

**Create session with BotBrowser:**
```
Create a browser session using the "us" BotBrowser profile with headless mode enabled.
```

**Automated workflow:**
```
Using the BotBrowser session:
1. Navigate to https://protected-site.com
2. Accept cookies if a banner appears
3. Fill the login form with username "test" and password "test123"
4. Click the login button
5. Take a screenshot of the result
```

Claude Code will automatically:
- Use the BotBrowser anti-detection profile
- Handle cookie banners intelligently
- Execute the workflow with proper fingerprint masking

---

## Environment Variables

When running in Docker, these environment variables are pre-configured:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER` | `true` | Indicates Docker environment (auto-set) |
| `BROWSER_PATH` | `/usr/bin/chromium-browser` | Chromium binary path |
| `BROWSER_HEADLESS` | `true` | Forced to true in Docker |
| `BROWSER_TIMEOUT` | `120` | Browser operation timeout (seconds) |
| `LOG_LEVEL` | `info` | Logging verbosity |
| `PORT` | `3000` | HTTP server port |
| `HOST` | `0.0.0.0` | HTTP server bind address |

### Override Variables

```bash
docker run -d \
  --name ferrum-mcp \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  -e LOG_LEVEL=debug \
  -e BROWSER_TIMEOUT=180 \
  ferrum-mcp:latest
```

---

## Security

### Headless Mode Enforcement

**Important**: In Docker, **headless mode is mandatory and automatically enforced**.

When creating a session:
- ✅ `headless: true` or omitted → Session created
- ❌ `headless: false` → **Error: "Headless mode is required when running in Docker"**

This is a security measure because:
- GUI applications don't work properly in containers
- X11 forwarding creates security risks
- Headless mode is more stable and performant

### Non-Root User

The container runs as user `ferrum` (UID 1000):

```bash
# Verify user
docker exec <container_id> whoami
# Output: ferrum

docker exec <container_id> id
# Output: uid=1000(ferrum) gid=1000(ferrum)
```

### Required Security Options

**`--security-opt seccomp=unconfined`** is required for Chromium to function.

Alternative (more restrictive but complex):
```bash
docker run -d \
  --name ferrum-mcp \
  --cap-add=SYS_ADMIN \
  -p 3000:3000 \
  ferrum-mcp:latest
```

### File Permissions

All files in `/app` are owned by `ferrum:ferrum`:

```bash
docker exec <container_id> ls -la /app
# drwxr-xr-x ferrum ferrum ...
```

---

## Troubleshooting

### Container Won't Start

**Check Docker logs:**
```bash
docker logs <container_id>
```

**Common issues:**
- Missing `--security-opt seccomp=unconfined`
- Port 3000 already in use
- Insufficient memory

### Health Check Fails

**Test manually:**
```bash
curl http://localhost:3000/health
# Expected: {"status":"ok"}
```

**Check container health:**
```bash
docker ps
# Look for (healthy) or (unhealthy)
```

### Session Creation Fails

**Error: "Headless mode is required"**
- You tried to create a session with `headless: false`
- Solution: Remove the `headless` parameter or set it to `true`

**Error: "Browser timeout"**
- Increase `BROWSER_TIMEOUT` environment variable
- Check available memory

### Claude Desktop Can't Connect

**Verify image exists:**
```bash
docker images ferrum-mcp:latest
```

**Check configuration:**
- Verify JSON syntax in `claude_desktop_config.json`
- Ensure `ferrum-mcp:latest` is the correct image tag

**Rebuild image:**
```bash
docker build -t ferrum-mcp:latest .
```

**Restart Claude Desktop:**
- Completely quit Claude Desktop
- Start it again

### Performance Issues

**Increase memory allocation:**

Docker Desktop → Settings → Resources → Memory (recommended: 4GB+)

**Monitor container resources:**
```bash
docker stats <container_id>
```

### Logs Location

**Container logs:**
```bash
docker logs <container_id>

# Follow logs in real-time
docker logs -f <container_id>

# Last 100 lines
docker logs --tail 100 <container_id>
```

**Application logs (inside container):**
```bash
docker exec <container_id> cat logs/ferrum_mcp.log
```

---

## Advanced Usage

### Custom Dockerfile

If you need to customize the image:

```dockerfile
FROM ferrum-mcp:latest

# Add custom fonts
RUN apk add --no-cache font-custom

# Add custom scripts
COPY scripts/ /app/scripts/

# Environment variables
ENV CUSTOM_VAR=value
```

Build:
```bash
docker build -t ferrum-mcp:custom .
```

### Volume Mounts

**Mount logs directory:**
```bash
docker run -d \
  --name ferrum-mcp \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  -v $(pwd)/logs:/app/logs \
  ferrum-mcp:latest
```

**Note**: Files will be owned by UID 1000 (ferrum user)

### Multi-Container Setup

For load balancing or testing:

```yaml
version: '3.8'

services:
  ferrum-mcp-1:
    image: ferrum-mcp:latest
    security_opt:
      - seccomp:unconfined
    ports:
      - "3001:3000"

  ferrum-mcp-2:
    image: ferrum-mcp:latest
    security_opt:
      - seccomp:unconfined
    ports:
      - "3002:3000"
```

### Inspect Container

```bash
# Enter container shell
docker exec -it <container_id> sh

# Check processes
docker top <container_id>

# Inspect configuration
docker inspect <container_id>
```

---

## Migration from Local to Docker

### 1. Test Locally First

```bash
# Start container
docker run -d -p 3000:3000 --security-opt seccomp=unconfined ferrum-mcp:latest

# Test health check
curl http://localhost:3000/health

# Create a test session
curl -X POST http://localhost:3000/mcp/v1 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"create_session","arguments":{"headless":true}}}'
```

### 2. Update Claude Desktop Config

Replace local Ruby configuration with Docker configuration (see [Claude Desktop Integration](#claude-desktop-integration))

### 3. Restart Claude Desktop

### 4. Verify

Ask Claude to perform a simple navigation task.

---

## Next Steps

- [API Reference](API_REFERENCE.md) - Learn about available tools
- [Configuration](CONFIGURATION.md) - Advanced configuration options
- [Deployment](DEPLOYMENT.md) - Production deployment strategies
- [Troubleshooting](TROUBLESHOOTING.md) - Detailed troubleshooting guide
