# Configuration Guide

This guide covers all configuration options for FerrumMCP.

## Environment Variables

All configuration is done via environment variables. You can set them in a `.env` file in the project root or export them in your shell.

See `.env.example` for a complete example configuration.

## Server Configuration

### Basic Server Options

| Variable | Description | Default |
|----------|-------------|---------|
| `MCP_SERVER_HOST` | HTTP server host | `0.0.0.0` |
| `MCP_SERVER_PORT` | HTTP server port | `3000` |
| `LOG_LEVEL` | Logging level (debug/info/warn/error) | `info` |

### Browser Defaults

| Variable | Description | Default |
|----------|-------------|---------|
| `BROWSER_HEADLESS` | Run browser in headless mode | `true` |
| `BROWSER_TIMEOUT` | Browser timeout in seconds | `60` |

### Session Management

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_CONCURRENT_SESSIONS` | Maximum number of concurrent browser sessions | `10` |

**Note**: When the session limit is reached, new session creation will fail with an error. Close unused sessions to free up capacity.

## Multi-Browser Configuration

FerrumMCP supports multiple browser configurations using structured environment variables.

### Browser Configuration Format

```bash
BROWSER_<ID>=type:path:name:description
```

**Parameters:**
- `<ID>`: Unique identifier (e.g., `CHROME`, `BOTBROWSER`, `EDGE`)
- `type`: Browser type (chrome, chromium, edge, brave, botbrowser)
- `path`: Path to browser executable (leave empty for system default)
- `name`: Human-readable name
- `description`: Optional description

**Examples:**

```bash
# Use system Chrome
BROWSER_CHROME=chrome::Google Chrome:Standard browser

# Specify custom Chrome path
BROWSER_CHROME=chrome:/usr/bin/google-chrome:Google Chrome:Standard browser

# Microsoft Edge
BROWSER_EDGE=edge:/usr/bin/microsoft-edge:Microsoft Edge:Edge browser

# Brave Browser
BROWSER_BRAVE=brave:/Applications/Brave Browser.app/Contents/MacOS/Brave Browser:Brave:Privacy-focused browser

# BotBrowser (anti-detection)
BROWSER_BOTBROWSER=botbrowser:/opt/botbrowser/chrome:BotBrowser:Anti-detection browser
```

### Supported Browser Types

- `chrome` - Google Chrome
- `chromium` - Chromium
- `edge` - Microsoft Edge
- `brave` - Brave Browser
- `botbrowser` - BotBrowser (requires separate installation)

## User Profile Configuration

Chrome user profiles allow you to maintain separate browsing contexts with different extensions, cookies, and settings.

### Profile Configuration Format

```bash
USER_PROFILE_<ID>=path:name:description
```

**Examples:**

```bash
USER_PROFILE_DEV=/home/user/.chrome-dev:Development:Dev profile with extensions
USER_PROFILE_TEST=/home/user/.chrome-test:Testing:Clean testing profile
USER_PROFILE_PROD=/home/user/.chrome-prod:Production:Production environment
```

## BotBrowser Profile Configuration

BotBrowser profiles contain fingerprinting configurations for anti-detection.

### Profile Configuration Format

```bash
BOT_PROFILE_<ID>=path:name:description
```

**Examples:**

```bash
# Encrypted profiles (recommended)
BOT_PROFILE_US=/profiles/us_chrome.enc:US Chrome:US-based Chrome fingerprint
BOT_PROFILE_EU=/profiles/eu_firefox.enc:EU Firefox:EU-based Firefox fingerprint
BOT_PROFILE_MOBILE=/profiles/android.enc:Android:Mobile Android fingerprint

# Unencrypted profiles
BOT_PROFILE_TEST=/profiles/test_profile.json:Test Profile:Testing profile
```

**Note:** Profiles ending in `.enc` are automatically recognized as encrypted.

## Resource Discovery

AI agents can discover available configurations through MCP Resources:

- `ferrum://browsers` - List all configured browsers
- `ferrum://user-profiles` - List all user profiles
- `ferrum://bot-profiles` - List all BotBrowser profiles
- `ferrum://capabilities` - Server capabilities

This allows AI to dynamically select the appropriate browser/profile for each task.

## Legacy Configuration (Deprecated)

For backward compatibility, these variables still work but are deprecated:

```bash
BROWSER_PATH=/usr/bin/google-chrome          # Creates browser with id "default"
BOTBROWSER_PATH=/opt/botbrowser/chrome       # Creates BotBrowser with id "default"
BOTBROWSER_PROFILE=/profiles/profile.enc     # Creates bot profile with id "default"
```

**Recommendation:** Use the new multi-configuration format for better flexibility.

## Session Configuration

### Session Limits (Coming in v1.1)

```bash
MAX_CONCURRENT_SESSIONS=10    # Maximum concurrent browser sessions
SESSION_IDLE_TIMEOUT=1800     # Auto-close after 30 minutes (seconds)
SESSION_CLEANUP_INTERVAL=300  # Cleanup check every 5 minutes (seconds)
```

**Note:** Session limits are currently hardcoded but will be configurable in v1.1.

## Whisper Configuration (CAPTCHA Solving)

```bash
WHISPER_MODEL=base              # Model: tiny, base, small, medium
WHISPER_MODELS_PATH=~/.whisper.cpp/models/  # Model storage location
```

Models are automatically downloaded on first use.

## Example Complete Configuration

```bash
# Server
MCP_SERVER_HOST=0.0.0.0
MCP_SERVER_PORT=3000
LOG_LEVEL=info

# Browser Defaults
BROWSER_HEADLESS=true
BROWSER_TIMEOUT=60

# Browsers
BROWSER_CHROME=chrome::Google Chrome:Standard browser
BROWSER_BOTBROWSER=botbrowser:/opt/botbrowser/chrome:BotBrowser:Anti-detection

# User Profiles
USER_PROFILE_DEV=/home/user/.chrome-dev:Development:Dev profile
USER_PROFILE_PROD=/home/user/.chrome-prod:Production:Prod profile

# BotBrowser Profiles
BOT_PROFILE_US=/profiles/us.enc:US Chrome:US fingerprint
BOT_PROFILE_EU=/profiles/eu.enc:EU Firefox:EU fingerprint

# Whisper (CAPTCHA)
WHISPER_MODEL=base
```

## Configuration Validation

FerrumMCP validates all configuration at startup:

- Browser paths are checked for existence
- Profile paths are verified
- Invalid configurations log warnings
- Fallbacks to defaults when possible

Check logs at `logs/ferrum_mcp.log` for validation messages.

## Using Configuration in Sessions

When creating sessions, you can reference configured browsers and profiles:

```ruby
# Use configured browser by ID
create_session(browser_id: "botbrowser")

# Use configured user profile
create_session(browser_id: "chrome", user_profile_id: "dev")

# Use configured bot profile
create_session(browser_id: "botbrowser", bot_profile_id: "us")

# Custom configuration (overrides defaults)
create_session(
  browser_id: "chrome",
  headless: false,
  timeout: 120,
  browser_options: { '--window-size': '1920,1080' }
)
```

## Docker Configuration

When using Docker, pass environment variables with `-e` or `--env-file`:

```bash
# Individual variables
docker run -e BROWSER_HEADLESS=false -p 3000:3000 eth3rnit3/ferrum-mcp

# From .env file
docker run --env-file .env -p 3000:3000 eth3rnit3/ferrum-mcp
```

## Next Steps

- See [Getting Started](GETTING_STARTED.md) for basic setup
- Read [API Reference](API_REFERENCE.md) for tool documentation
- Check [BotBrowser Integration](BOTBROWSER_INTEGRATION.md) for anti-detection setup
