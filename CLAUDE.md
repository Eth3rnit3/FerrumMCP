# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FerrumMCP is a browser automation server implementing the Model Context Protocol (MCP). It provides AI assistants with browser automation capabilities through a standardized interface, using Ferrum (Ruby's headless Chrome driver) and optional BotBrowser integration for anti-detection.

## Architecture

### Core Components

**Server Layer** (`lib/ferrum_mcp/bin/ferrum-mcp`)
- `FerrumMCP::Server`: Main MCP server implementation
- Manages 41 browser automation tools organized into 7 categories (Session Management, Navigation, Interaction, Extraction, Waiting, Tabs & Viewport, Advanced)
- Tools are defined in `TOOL_CLASSES` constant and registered with the MCP server at initialization
- **Session-based architecture**: All browser operations require an explicit session

**Session Management** (`lib/ferrum_mcp/session_manager.rb`, `lib/ferrum_mcp/session.rb`)
- `SessionManager`: Thread-safe session pool with automatic cleanup
- `Session`: Encapsulates a browser instance with custom configuration
- Supports multiple concurrent browser sessions with different configurations
- Each session can use different browser types (Chrome, BotBrowser), options, and profiles
- Session lifecycle: create → use → auto-cleanup (after 30min idle) or manual close
- **Important**: All browser tools require a valid `session_id` parameter

**Browser Management** (`lib/ferrum_mcp/browser_manager.rb`)
- `BrowserManager`: Handles Ferrum browser lifecycle
- Supports both standard Chrome/Chromium and BotBrowser (anti-detection mode)
- Browser options configured via `browser_options` method with anti-automation flags
- Each session has its own `BrowserManager` with custom configuration

**Transport Layer** (`lib/ferrum_mcp/transport/`)
- Two transport implementations:
  - `HTTPServer`: Uses MCP's `StreamableHTTPTransport` with Puma/Rack
  - `StdioServer`: Uses MCP's `StdioTransport` for standard I/O communication
- Transport is selected at startup via `--transport` flag (http or stdio)

**Tool Architecture** (`lib/ferrum_mcp/tools/`)
- Browser tools inherit from `BaseTool`, session-management tools from `SessionTool`; both use the `Definition` DSL
- A tool declares `tool_name`, `description` and `param`s; `input_schema` is generated, `session_id` is injected for browser tools, and `#perform(params)` receives symbol keys with defaults applied
- Tools use `success_response`, `error_response`, or `image_response` helper methods
- Tools act on the session's **current tab** (`page`, a `Ferrum::Page`); `browser` is the `Ferrum::Browser`
- `find_element` / `find_elements` accept CSS, XPath (`xpath:` prefix or `//`) and snapshot refs (`ref:e12`)
- `snapshot` tags elements with `data-fmcp-ref`; refs stay stable until the document changes

**Configuration** (`lib/ferrum_mcp/configuration.rb`)
- Multi-browser and multi-profile support via structured ENV variables
- Supports multiple browsers, user profiles, and BotBrowser profiles
- Logging to `LOG_FILE` (path or `stderr`), default `./logs/ferrum_mcp.log` under the working directory; never STDOUT
- Optional `UrlPolicy` (`ALLOWED_HOSTS` / `BLOCKED_HOSTS`) and `UPLOAD_ALLOWED_DIRS`
- Validates all configured browser paths at startup
- Backward compatible with legacy `BROWSER_PATH` and `BOTBROWSER_PROFILE` variables

**Resource Manager** (`lib/ferrum_mcp/resource_manager.rb`)
- Exposes server capabilities and configurations as MCP Resources
- Provides AI agents with discovery of available browsers and profiles
- Resources include: browsers, user profiles, bot profiles, and server capabilities
- All resources accessible via `ferrum://` URI scheme

### Dependency Management

Uses Zeitwerk for autoloading with custom inflections for acronyms (MCP, HTML, URL, JS). The loader is configured in `lib/ferrum_mcp.rb` and eager loads in production, lazy loads in development.

## Development Commands

### Running the Server

```bash
# Start with HTTP transport (default)
ruby bin/ferrum-mcp
# or explicitly
ruby bin/ferrum-mcp --transport http

# Start with STDIO transport (for MCP clients like Claude Desktop)
ruby bin/ferrum-mcp --transport stdio

# View help
ruby bin/ferrum-mcp --help

# View version
ruby bin/ferrum-mcp --version
```

### Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/ferrum_mcp/tools/navigation_tools_spec.rb

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Unit tests only (no Chrome, a few seconds) / integration tests only
rake test:unit
rake test:integration
```

Tests use a WEBrick test server on port 9999 (override with `TEST_SERVER_PORT`) started in `spec_helper.rb`. Specs under `spec/ferrum_mcp/tools/` and `spec/integration/` are tagged `:integration` and drive a real headless Chrome; the rest stub `Ferrum::Browser`. All tests run with error-level logging.

### Linting

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -A

# Via Rake
rake rubocop
rake rubocop_fix
```

### Rake Tasks

```bash
# Check environment configuration
rake check_env

# List all available tools
rake list_tools

# Run tests
rake test

# Generate a secure API key
rake generate_api_key
```

## Session Management

### Creating and Using Sessions

**All browser operations require a session**. You must create a session before using any browser automation tools:

```ruby
# 1. Create a session (returns session_id)
session_id = create_session(
  headless: true,
  timeout: 60,
  browser_options: { '--window-size': '1920,1080' }
)

# 2. Use the session_id with any browser tool
navigate(url: "https://example.com", session_id: session_id)
screenshot(session_id: session_id)

# 3. Close the session when done (or it auto-closes after 30min idle)
close_session(session_id: session_id)
```

### Multiple Concurrent Sessions

You can run multiple browsers in parallel with different configurations:

```ruby
# Standard Chrome for simple tasks
chrome_session = create_session(headless: true)

# BotBrowser with anti-detection for protected sites
bot_session = create_session(
  browser_path: '/path/to/botbrowser',
  botbrowser_profile: '/path/to/profile'
)

# Use them concurrently
navigate(url: "https://api.example.com", session_id: chrome_session)
navigate(url: "https://protected-site.com", session_id: bot_session)
```

### Session Tools

- `create_session`: Create a new browser session with custom options
- `list_sessions`: List all active sessions
- `get_session_info`: Get detailed information about a session
- `close_session`: Manually close a session

## MCP Resources - Browser & Profile Discovery

The server exposes its configuration through **MCP Resources**, allowing AI agents to discover available browsers, profiles, and capabilities before creating sessions.

### Available Resources

All resources use the `ferrum://` URI scheme and return JSON data:

1. **`ferrum://browsers`** - List all configured browsers
   - Returns: Array of browsers with id, name, type, path, description
   - Indicates which browser is the default

2. **`ferrum://browsers/{id}`** - Details for a specific browser
   - Returns: Full browser configuration plus usage examples

3. **`ferrum://user-profiles`** - List all Chrome user profiles
   - Returns: Array of user profiles with id, name, path, description

4. **`ferrum://user-profiles/{id}`** - Details for a specific user profile
   - Returns: Full profile configuration plus usage examples

5. **`ferrum://bot-profiles`** - List all BotBrowser profiles
   - Returns: Array of bot profiles with encryption status
   - Includes anti-detection feature list

6. **`ferrum://bot-profiles/{id}`** - Details for a specific bot profile
   - Returns: Full profile with supported anti-detection features

7. **`ferrum://capabilities`** - Server capabilities and feature flags
   - Returns: Version, available features, transport mode, counts

### Configuring Browsers and Profiles

Configuration is done via environment variables in `.env` file:

**Multi-Browser Configuration:**
```bash
# Format: BROWSER_<ID>=type:path:name:description
BROWSER_CHROME=chrome:/usr/bin/google-chrome:Google Chrome:Standard browser
BROWSER_BOTBROWSER=botbrowser:/opt/botbrowser/chrome:BotBrowser:Anti-detection browser
BROWSER_EDGE=edge:/usr/bin/microsoft-edge:Edge:Microsoft Edge browser
```

**User Profile Configuration:**
```bash
# Format: USER_PROFILE_<ID>=path:name:description
USER_PROFILE_DEV=/home/user/.chrome-dev:Development:Dev profile with extensions
USER_PROFILE_TEST=/home/user/.chrome-test:Testing:Clean testing profile
USER_PROFILE_PROD=/home/user/.chrome-prod:Production:Production environment
```

**BotBrowser Profile Configuration:**
```bash
# Format: BOT_PROFILE_<ID>=path:name:description
BOT_PROFILE_US=/profiles/us_chrome.enc:US Chrome:US-based Chrome fingerprint
BOT_PROFILE_EU=/profiles/eu_firefox.enc:EU Firefox:EU-based Firefox fingerprint
BOT_PROFILE_MOBILE=/profiles/android.enc:Android:Mobile Android fingerprint
```

### Using Discovered Resources

AI agents should:
1. **Query `ferrum://capabilities`** to check if multi-browser/profile support is enabled
2. **Query `ferrum://browsers`** to see available browser options
3. **Query `ferrum://bot-profiles`** if BotBrowser integration is needed
4. **Use the `id`** from resources when creating sessions

Example workflow:
```ruby
# Agent queries resources first
capabilities = read_resource('ferrum://capabilities')
# -> { "features": { "botbrowser_integration": true, ... } }

browsers = read_resource('ferrum://browsers')
# -> { "browsers": [{ "id": "botbrowser", "type": "botbrowser", ... }] }

# Agent creates session using discovered browser_id
session_id = create_session(browser_id: "botbrowser", bot_profile_id: "us")
```

### Legacy Compatibility

Old environment variables still work:
- `BROWSER_PATH` → creates browser with id `"default"`
- `BOTBROWSER_PATH` → creates BotBrowser with id `"default"`
- `BOTBROWSER_PROFILE` → creates bot profile with id `"default"`

## Adding New Tools

1. Create tool file in `lib/ferrum_mcp/tools/` (e.g., `my_tool.rb`)
2. Inherit from `BaseTool` (browser tool) or `SessionTool` (session management) and declare the interface with the DSL:
   - `tool_name 'my_tool'`: String identifier for MCP
   - `description '...'`: Human-readable description
   - `param :name, type:, description:, required:, default:, enum:, schema:`: one line per parameter (`session_id` is added automatically for browser tools)
   - `#perform(params)`: Main logic, returns `success_response(data)`, `image_response(...)` or `error_response(message)`
3. Add to `TOOL_CLASSES` array in `lib/ferrum_mcp/server.rb`
4. Add an integration spec under `spec/ferrum_mcp/tools/` and document the tool in `docs/API_REFERENCE.md`

Example:
```ruby
module FerrumMCP
  module Tools
    class HighlightTool < BaseTool
      tool_name 'highlight'
      description 'Outline an element in red'

      param :selector, type: :string, required: true, description: 'CSS selector, XPath or snapshot ref'
      param :color, type: :string, default: 'red', description: 'CSS color (default: red)'

      def perform(params)
        element = find_element(params[:selector])
        page.execute("arguments[0].style.outline = '3px solid ' + arguments[1]", element, params[:color])
        success_response(message: "Highlighted #{params[:selector]}")
      rescue StandardError => e
        error_response("Failed to highlight: #{e.message}")
      end
    end
  end
end
```

## Environment Variables

### Server Configuration
- `MCP_SERVER_HOST`: HTTP server host (default: 0.0.0.0)
- `MCP_SERVER_PORT`: HTTP server port (default: 3000)
- `BROWSER_HEADLESS`: Run headless (default: false)
- `BROWSER_TIMEOUT`: Browser timeout in seconds (default: 60)
- `LOG_LEVEL`: Logging level - debug/info/warn/error (default: info)
- `LOG_FILE`: Log destination, a path or `stderr` (default: `./logs/ferrum_mcp.log`)
- `TRUST_PROXY`: Honour `X-Forwarded-For` for rate limiting/audit (default: false; only behind a trusted proxy)
- `ALLOWED_HOSTS` / `BLOCKED_HOSTS`: Optional navigation policy (exact host, `*.suffix`, CIDR)
- `UPLOAD_ALLOWED_DIRS`: Directories `upload_file` may read from (default: cwd and temp dir)

### API Key Authentication (HTTP Transport only)
- `API_KEY_ENABLED`: Enable Bearer token authentication (default: false)
- `API_KEY`: Single API key for authentication
- `API_KEYS`: Comma-separated list of valid API keys (for multiple clients or key rotation)

When enabled, the `/mcp` endpoint requires an `Authorization: Bearer <api_key>` header.
The `/health` and `/` endpoints remain accessible without authentication for monitoring purposes.

### Multi-Browser Configuration (Recommended)
- `BROWSER_<ID>`: Browser configuration in format `type:path:name:description`
  - Example: `BROWSER_CHROME=chrome:/usr/bin/google-chrome:Chrome:Standard browser`
  - Supported types: chrome, chromium, edge, brave, botbrowser
  - Leave path empty to use system default: `BROWSER_CHROME=chrome::Chrome:System Chrome`

### User Profile Configuration
- `USER_PROFILE_<ID>`: Chrome user profile in format `path:name:description`
  - Example: `USER_PROFILE_DEV=/home/user/.chrome-dev:Development:Dev profile`

### BotBrowser Profile Configuration
- `BOT_PROFILE_<ID>`: BotBrowser profile in format `path:name:description`
  - Example: `BOT_PROFILE_US=/profiles/us.enc:US Chrome:US fingerprint`
  - Profiles ending in `.enc` are automatically marked as encrypted

### Legacy Configuration (Deprecated but Supported)
- `BROWSER_PATH` / `BOTBROWSER_PATH`: Path to browser executable (creates browser with id "default")
- `BOTBROWSER_PROFILE`: Path to BotBrowser profile (creates profile with id "default")

All environment variables can be set via `.env` file in project root (automatically loaded by `bin/ferrum-mcp`).
See `.env.example` for detailed configuration examples.

## Key Implementation Details

- **Tool Execution Flow**: `Server#execute_tool` → `Tool.requires_session?` → validates `session_id` → `SessionManager#with_session` (starts or restarts the browser if needed) → `tool.execute` (normalizes params) → `tool.perform` → wraps result in `MCP::Tool::Response`
- **Resource Discovery**: `ResourceManager` builds MCP resources from configuration at server startup; `Server#setup_resources` registers `resources_read_handler` for dynamic resource reading
- **Session Management**: `SessionManager#with_session(session_id)` provides thread-safe access to browser
- **Multi-Configuration**: `Configuration` parses ENV variables on initialization, creating `BrowserConfig`, `UserProfileConfig`, and `BotProfileConfig` structs
- **Error Handling**: MCP exception reporter configured in `Server#setup_error_handling` logs to file
- **Image Responses**: Screenshot tool returns base64 image data with `type: 'image'` and `mime_type`
- **Element Finding**: `BaseTool#find_element` includes retry logic with configurable timeout
- **Browser State**: Each session's browser remains active until session is closed or idle timeout (30min); a dead Chrome process (`BrowserManager#healthy?`) is restarted on the next call, and a `Ferrum::DeadBrowserError` inside a tool marks the session inactive
- **Locking**: `SessionManager` holds its global mutex only for map operations; browsers are stopped outside of it. `Session` has a `closed` state so a closed session cannot be restarted
- **Auto-cleanup**: Background thread cleans up idle sessions every 5 minutes
- **Thread Safety**: All session operations are protected by mutex locks
