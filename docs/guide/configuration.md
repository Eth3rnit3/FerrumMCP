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
| `LOG_FILE` | Log destination: a file path or `stderr` | `./logs/ferrum_mcp.log` |
| `TRUST_PROXY` | Use `X-Forwarded-For` for rate limiting and audit logs (only behind a trusted proxy) | `false` |
| `DNS_REBINDING_PROTECTION` | Validate the `Host` and `Origin` headers on `/mcp` | `true` |
| `MCP_ALLOWED_HOSTS` | Extra `Host` values accepted besides loopback (`name` for any port, or `name:port`) | none |
| `MCP_ALLOWED_ORIGINS` | Extra browser `Origin` values accepted besides same-origin | none |

**Logging**: logs never go to STDOUT because the stdio transport uses it for the protocol. The default file lives
under the current working directory (never inside the installed gem); when that directory is not writable the
server falls back to the system temp directory. Use `LOG_FILE=stderr` in containers.

### Browser Defaults

| Variable | Description | Default |
|----------|-------------|---------|
| `BROWSER_HEADLESS` | Run browser in headless mode | `false` |
| `BROWSER_TIMEOUT` | Browser timeout in seconds | `60` |
| `FERRUM_RUNTIME_ENABLE` | `true` enables the CDP Runtime domain as stock Ferrum does. By default it stays off, because pages can detect it through console serialization; JavaScript still runs in the page's main world. | `false` |

### Session Management

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_CONCURRENT_SESSIONS` | Maximum number of concurrent browser sessions | `10` |

**Note**: When the session limit is reached, new session creation will fail with an error. Close unused sessions to free up capacity.

### Rate Limiting (HTTP Transport Only)

| Variable | Description | Default |
|----------|-------------|---------|
| `RATE_LIMIT_ENABLED` | Enable/disable rate limiting | `true` |
| `RATE_LIMIT_MAX_REQUESTS` | Maximum requests per time window | `100` |
| `RATE_LIMIT_WINDOW` | Time window in seconds | `60` |

**Note**: Rate limiting is applied per client IP address. When exceeded, HTTP 429 (Too Many Requests) is returned with a `Retry-After` header.
The client address is the socket peer unless `TRUST_PROXY=true`, in which case the first `X-Forwarded-For` entry is used.
Never enable `TRUST_PROXY` on a server reachable directly by clients: they could rotate the header to escape the limit.

**DNS rebinding protection**: the MCP SDK rejects (HTTP 403) a request on `/mcp` whose `Host` header is neither
loopback nor listed in `MCP_ALLOWED_HOSTS`, and a browser request whose `Origin` is neither same-origin nor listed in
`MCP_ALLOWED_ORIGINS`. A server reached through a host name or IP other than `localhost` must list it
(`MCP_ALLOWED_HOSTS=mcp.example.com,192.168.1.10`). Behind a reverse proxy, either list the public host name the
proxy forwards, or set `DNS_REBINDING_PROTECTION=false` when the proxy validates `Host` itself.

### Navigation Policy

| Variable | Description | Default |
|----------|-------------|---------|
| `ALLOWED_HOSTS` | Comma-separated hosts that may be visited (only these when set) | _(unset)_ |
| `BLOCKED_HOSTS` | Comma-separated hosts that may never be visited (wins over the allow list) | _(unset)_ |

Entries accept an exact host (`example.com`), a wildcard suffix (`*.example.com`, which also matches
`example.com`) or a CIDR range for IP literals (`10.0.0.0/8`). The policy is enforced by `navigate` and
`new_tab` before the browser is touched. It checks the URL as written and does not resolve DNS, so treat it
as a guard rail for exposed HTTP deployments rather than a full SSRF defense.

```bash
BLOCKED_HOSTS=localhost,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,*.internal
```

### File Uploads

| Variable | Description | Default |
|----------|-------------|---------|
| `UPLOAD_ALLOWED_DIRS` | Comma-separated directories `upload_file` may read from | current directory, temp dir |

The `upload_file` tool attaches files from the **server's** filesystem. Paths are resolved (symlinks included)
and must live under one of the allowed directories.

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

### Session Limits

```bash
MAX_CONCURRENT_SESSIONS=10    # Maximum concurrent browser sessions (default: 10)
```

Idle sessions close after 30 minutes; the cleanup runs every 5 minutes. Both are fixed.

## Whisper Configuration (CAPTCHA Solving)

Only reCAPTCHA's audio challenge needs Whisper; Turnstile and hCaptcha don't.
Requires `whisper-cli` (whisper.cpp) and, recommended, `ffmpeg`.

```bash
WHISPER_PATH=whisper-cli        # whisper.cpp binary
WHISPER_MODEL=base.en           # Transcription model (tiny, base, small, medium, their .en variants,
                                # large-v3-turbo) or a path to a .bin file
WHISPER_LID_MODEL=small         # Multilingual model used to spot reCAPTCHA's decoy audio
WHISPER_LANGUAGE=en             # Expected audio language ("auto" disables the language check)
FFMPEG_PATH=ffmpeg              # Converts audio to 16 kHz mono WAV
CAPTCHA_AUDIO_DIR=              # Optional: keep every challenge audio and its transcription
```

Models are stored in `~/.whisper.cpp/models/` and downloaded on first use.

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
WHISPER_MODEL=base.en
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

- See [Getting Started](/guide/getting-started) for basic setup
- Read [API Reference](/reference/) for tool documentation
- Check [BotBrowser in Docker](/deployment/botbrowser-docker) for anti-detection setup
