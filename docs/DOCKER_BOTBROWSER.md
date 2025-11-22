# Docker with BotBrowser Integration

This guide explains how to build and run FerrumMCP Docker images with BotBrowser support for anti-detection capabilities.

## Overview

FerrumMCP supports two Docker image variants:

1. **Standard** (`Dockerfile`): Uses system Chromium - lightweight, faster builds
2. **BotBrowser** (`Dockerfile.with-botbrowser`): Includes BotBrowser binary - anti-detection

## BotBrowser vs Standard Chromium

| Feature | Standard Chromium | BotBrowser |
|---------|-------------------|------------|
| Size | ~1.96GB | ~2.5GB+ |
| Anti-detection | Basic | Advanced |
| Fingerprint masking | No | Yes |
| Profile support | No | Yes (encrypted profiles) |
| Use case | General automation | Protected sites, account creation |

---

## Prerequisites

### BotBrowser Binary

BotBrowser is **open-source** but the browser binary must be obtained separately:

1. **Download from GitHub Releases**:
   ```bash
   # Visit https://github.com/MiddleSchoolStudent/BotBrowser/releases
   # Download the latest Linux binary for your architecture (amd64/arm64)
   ```

2. **Or compile from source**:
   ```bash
   git clone https://github.com/MiddleSchoolStudent/BotBrowser.git
   cd BotBrowser
   # Follow compilation instructions in the repository
   ```

### BotBrowser Profiles (Optional)

Encrypted profiles are **licensed separately** and should be obtained from:
- BotBrowser team directly
- Authorized resellers
- Your own generated profiles (requires private key)

**Note**: The Docker image doesn't include profiles - they should be mounted as volumes at runtime.

---

## Building the Image

### Option 1: Copy BotBrowser Binary from Build Context

1. **Prepare BotBrowser directory**:
   ```bash
   cd /path/to/ferrum-mcp
   mkdir -p botbrowser

   # Copy BotBrowser binary (adjust paths)
   cp /path/to/botbrowser/chrome botbrowser/
   cp -r /path/to/botbrowser/lib* botbrowser/  # Copy required libraries
   ```

2. **Build the image**:
   ```bash
   docker build \
     -f Dockerfile.with-botbrowser \
     --build-arg INCLUDE_BOTBROWSER=true \
     -t ferrum-mcp:botbrowser \
     .
   ```

### Option 2: Download During Build (Advanced)

Uncomment the download section in `Dockerfile.with-botbrowser` and provide the URL:

```bash
docker build \
  -f Dockerfile.with-botbrowser \
  --build-arg INCLUDE_BOTBROWSER=true \
  --build-arg BOTBROWSER_DOWNLOAD_URL=https://github.com/.../botbrowser-linux-amd64.tar.gz \
  -t ferrum-mcp:botbrowser \
  .
```

### Verify the Build

```bash
# Check image size
docker images ferrum-mcp:botbrowser

# Verify BotBrowser is present
docker run --rm ferrum-mcp:botbrowser ls -la /opt/botbrowser
```

---

## Running with BotBrowser

### Basic Usage (HTTP Transport)

```bash
docker run -d \
  --name ferrum-mcp-bot \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  ferrum-mcp:botbrowser
```

### With BotBrowser Profiles

Mount your encrypted profiles as a volume:

```bash
docker run -d \
  --name ferrum-mcp-bot \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  -v /path/to/profiles:/app/profiles:ro \
  -e BOT_PROFILE_US=/app/profiles/us_chrome.enc:US Chrome:US fingerprint \
  -e BOT_PROFILE_EU=/app/profiles/eu_firefox.enc:EU Firefox:EU fingerprint \
  ferrum-mcp:botbrowser
```

### Claude Desktop Integration

**Configuration** (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "ferrum-mcp-bot": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "--security-opt",
        "seccomp=unconfined",
        "-v",
        "/path/to/profiles:/app/profiles:ro",
        "-e",
        "BOT_PROFILE_US=/app/profiles/us.enc:US Profile:US Chrome fingerprint",
        "ferrum-mcp:botbrowser",
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

---

## Using BotBrowser Profiles

### Profile Configuration

Profiles are configured via environment variables:

```bash
BOT_PROFILE_<ID>=<path>:<name>:<description>
```

**Example**:
```bash
BOT_PROFILE_US=/app/profiles/us_chrome.enc:US Chrome:Chrome 142 US fingerprint
```

### Creating a Session with BotBrowser

Via MCP tools:

```json
{
  "name": "create_session",
  "arguments": {
    "browser_id": "botbrowser",
    "bot_profile_id": "us",
    "headless": true
  }
}
```

Or discover available profiles first:

```bash
# List available BotBrowser profiles
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

---

## Multi-Architecture Support

### Build for Specific Platform

```bash
# AMD64 (x86_64)
docker build \
  -f Dockerfile.with-botbrowser \
  --build-arg INCLUDE_BOTBROWSER=true \
  --platform linux/amd64 \
  -t ferrum-mcp:botbrowser-amd64 \
  .

# ARM64 (Apple Silicon, ARM servers)
docker build \
  -f Dockerfile.with-botbrowser \
  --build-arg INCLUDE_BOTBROWSER=true \
  --platform linux/arm64 \
  -t ferrum-mcp:botbrowser-arm64 \
  .
```

### Multi-Arch Build with Buildx

```bash
docker buildx create --use
docker buildx build \
  -f Dockerfile.with-botbrowser \
  --build-arg INCLUDE_BOTBROWSER=true \
  --platform linux/amd64,linux/arm64 \
  -t ferrum-mcp:botbrowser \
  --push \
  .
```

---

## Profile Management

### Mounting Profiles

**Read-only mount** (recommended):
```bash
-v /path/to/profiles:/app/profiles:ro
```

**Read-write mount** (if profiles need updating):
```bash
-v /path/to/profiles:/app/profiles:rw
```

### Profile Directory Structure

```
profiles/
├── us_chrome_142.enc         # US Chrome profile
├── eu_firefox_126.enc         # EU Firefox profile
├── mobile_android.enc         # Mobile Android profile
└── ...
```

### Environment Variables for Profiles

```bash
docker run -d \
  -v $(pwd)/profiles:/app/profiles:ro \
  -e BOT_PROFILE_US=/app/profiles/us_chrome_142.enc:US:Chrome 142 US \
  -e BOT_PROFILE_EU=/app/profiles/eu_firefox_126.enc:EU:Firefox 126 EU \
  -e BOT_PROFILE_MOBILE=/app/profiles/mobile_android.enc:Mobile:Android 14 \
  ferrum-mcp:botbrowser
```

---

## Troubleshooting

### BotBrowser Not Found

**Error**: "BotBrowser binary not found at /opt/botbrowser/chrome"

**Solutions**:
1. Verify binary was copied during build:
   ```bash
   docker run --rm ferrum-mcp:botbrowser ls -la /opt/botbrowser
   ```

2. Check build logs for errors:
   ```bash
   docker build -f Dockerfile.with-botbrowser --no-cache . 2>&1 | grep -i bot
   ```

3. Ensure `INCLUDE_BOTBROWSER=true` was set during build

### Profile Not Loading

**Error**: "Failed to load BotBrowser profile"

**Solutions**:
1. Verify profile path is correct:
   ```bash
   docker exec <container> ls -la /app/profiles
   ```

2. Check file permissions (should be readable by UID 1000):
   ```bash
   ls -la /path/to/profiles
   # Files should be owned by user with UID 1000 or have read permissions for all
   ```

3. Verify profile is encrypted (`.enc` extension):
   ```bash
   file /path/to/profiles/*.enc
   # Should show: data (encrypted)
   ```

### Performance Issues

**Symptom**: BotBrowser slower than expected

**Solutions**:
1. Increase Docker memory allocation (recommended: 4GB+)
2. Use SSD for profile storage
3. Reduce concurrent sessions
4. Consider using `--cap-add=SYS_ADMIN` instead of `--security-opt seccomp=unconfined`

---

## Security Considerations

### Profile Encryption

- Profiles should always be encrypted (`.enc` files)
- Never commit unencrypted profiles to version control
- Use read-only mounts to prevent profile modification

### Container Isolation

- Run with non-root user (default: `ferrum`, UID 1000)
- Use `--security-opt seccomp=unconfined` only when necessary
- Consider network isolation for sensitive operations

### Profile Storage

**Best practices**:
```bash
# Encrypted profiles directory with restricted permissions
chmod 700 ~/botbrowser-profiles
chmod 600 ~/botbrowser-profiles/*.enc

# Mount read-only in container
-v ~/botbrowser-profiles:/app/profiles:ro
```

---

## Comparison with Standard Image

### When to Use Standard Image

✅ **Use Standard (`Dockerfile`)** when:
- General web scraping
- Internal tools/APIs
- Sites without anti-bot protection
- Quick prototyping
- Smaller image size needed

### When to Use BotBrowser Image

✅ **Use BotBrowser (`Dockerfile.with-botbrowser`)** when:
- Protected sites (Cloudflare, PerimeterX, etc.)
- Account creation at scale
- Social media automation
- E-commerce automation
- Advanced anti-detection required

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build BotBrowser Image

on:
  workflow_dispatch:
    inputs:
      botbrowser_url:
        description: 'BotBrowser download URL'
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download BotBrowser
        run: |
          mkdir -p botbrowser
          wget -O botbrowser.tar.gz ${{ github.event.inputs.botbrowser_url }}
          tar -xzf botbrowser.tar.gz -C botbrowser

      - name: Build Image
        run: |
          docker build \
            -f Dockerfile.with-botbrowser \
            --build-arg INCLUDE_BOTBROWSER=true \
            -t ferrum-mcp:botbrowser \
            .

      - name: Push to Registry
        run: |
          docker tag ferrum-mcp:botbrowser ${{ secrets.DOCKER_REGISTRY }}/ferrum-mcp:botbrowser
          docker push ${{ secrets.DOCKER_REGISTRY }}/ferrum-mcp:botbrowser
```

---

## Next Steps

- [Docker Deployment](DOCKER.md) - General Docker deployment guide
- [BotBrowser Integration](BOTBROWSER_INTEGRATION.md) - Detailed BotBrowser setup
- [Configuration](CONFIGURATION.md) - Environment variables reference
- [API Reference](API_REFERENCE.md) - All available tools

---

## Support

### Getting BotBrowser

- **GitHub**: https://github.com/MiddleSchoolStudent/BotBrowser
- **Releases**: https://github.com/MiddleSchoolStudent/BotBrowser/releases

### Getting Profiles

Profiles must be obtained separately:
- Contact BotBrowser team for trial profiles
- Purchase enterprise profiles
- Generate your own (requires private key from BotBrowser)

### Issues

- BotBrowser issues: https://github.com/MiddleSchoolStudent/BotBrowser/issues
- FerrumMCP issues: https://github.com/Eth3rnit3/FerrumMCP/issues
