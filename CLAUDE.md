# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FerrumMCP is a browser automation server implementing the Model Context Protocol (MCP). It provides AI assistants with browser automation capabilities through a standardized interface, using Ferrum (Ruby's headless Chrome driver) and optional BotBrowser integration for anti-detection.

## Architecture

### Core Components

**Server Layer** (`lib/ferrum_mcp/server.rb`)
- `FerrumMCP::Server`: Main MCP server implementation
- Manages 27+ browser automation tools organized into 6 categories (Session Management, Navigation, Interaction, Extraction, Waiting, Advanced)
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
- All tools inherit from `BaseTool`
- Each tool must implement: `execute(params)`, `.tool_name`, `.description`, `.input_schema`
- Tools use `success_response`, `error_response`, or `image_response` helper methods
- `find_element` helper with timeout support for element location

**Configuration** (`lib/ferrum_mcp/configuration.rb`)
- Environment-based configuration via ENV variables
- File-only logging (no console output) to `logs/ferrum_mcp.log`
- Validates browser path existence before startup

### Dependency Management

Uses Zeitwerk for autoloading with custom inflections for acronyms (MCP, HTML, URL, JS). The loader is configured in `lib/ferrum_mcp.rb` and eager loads in production, lazy loads in development.

## Development Commands

### Running the Server

```bash
# Start with HTTP transport (default)
ruby server.rb
# or explicitly
ruby server.rb --transport http

# Start with STDIO transport (for MCP clients like Claude Desktop)
ruby server.rb --transport stdio

# View help
ruby server.rb --help

# View version
ruby server.rb --version
```

### Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/ferrum_mcp/tools/navigation_tools_spec.rb

# Run tests with coverage
COVERAGE=true bundle exec rspec
```

Tests use a WEBrick test server on port 9999 started in `spec_helper.rb`. All tests run with headless browser and error-level logging.

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

## Adding New Tools

1. Create tool file in `lib/ferrum_mcp/tools/` (e.g., `my_tool.rb`)
2. Inherit from `BaseTool` and implement required methods:
   - `.tool_name`: String identifier for MCP
   - `.description`: Human-readable description
   - `.input_schema`: JSON schema for parameters
     - **IMPORTANT**: Add `session_id` as a **required** parameter in your schema
   - `#execute(params)`: Main logic, returns `success_response(data)` or `error_response(message)`
3. Add to `TOOL_CLASSES` array in `lib/ferrum_mcp/server.rb`
4. Tool will be auto-registered with MCP server at startup

Example schema with session_id:
```ruby
def self.input_schema
  {
    type: 'object',
    properties: {
      session_id: {
        type: 'string',
        description: 'Session ID to use for this operation'
      },
      # ... your other parameters
    },
    required: ['session_id', ...]  # session_id is REQUIRED
  }
end
```

## Environment Variables

- `BROWSER_PATH` / `BOTBROWSER_PATH`: Path to browser executable (optional, auto-detects system Chrome if not set)
- `BOTBROWSER_PROFILE`: Path to BotBrowser profile for anti-detection
- `BROWSER_HEADLESS`: Run headless (default: false)
- `BROWSER_TIMEOUT`: Browser timeout in seconds (default: 60)
- `MCP_SERVER_HOST`: HTTP server host (default: 0.0.0.0)
- `MCP_SERVER_PORT`: HTTP server port (default: 3000)
- `LOG_LEVEL`: Logging level - debug/info/warn/error (default: debug)

Can be set via `.env` file in project root (automatically loaded by `server.rb`).

## Key Implementation Details

- **Tool Execution Flow**: `Server#execute_tool` → validates `session_id` → gets session from `SessionManager` → starts browser if needed → creates tool instance → calls `tool.execute` → wraps result in `MCP::Tool::Response`
- **Session Management**: `SessionManager#with_session(session_id)` provides thread-safe access to browser
- **Error Handling**: MCP exception reporter configured in `Server#setup_error_handling` logs to file
- **Image Responses**: Screenshot tool returns base64 image data with `type: 'image'` and `mime_type`
- **Element Finding**: `BaseTool#find_element` includes retry logic with configurable timeout
- **Browser State**: Each session's browser remains active until session is closed or idle timeout (30min)
- **Auto-cleanup**: Background thread cleans up idle sessions every 5 minutes
- **Thread Safety**: All session operations are protected by mutex locks
