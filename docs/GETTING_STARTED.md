# Getting Started with FerrumMCP

## What is FerrumMCP?

FerrumMCP provides AI assistants with browser automation capabilities via the MCP protocol. It allows your AI to navigate websites, interact with elements, extract content, and take screenshots - all through a standardized interface.

**Key features:**
- 🌐 Full browser automation (navigate, click, fill forms, etc.)
- 📸 Screenshot capture (full page or specific elements)
- 🔍 Content extraction (text, HTML, attributes)
- 🍪 Cookie management
- ⚡ JavaScript execution
- 🔄 Session-based architecture with multiple concurrent browsers
- 🤖 Smart cookie banner detection and acceptance
- 🧩 CAPTCHA solving with Whisper AI (alpha)
- 🦾 BotBrowser integration for anti-detection

## Quick Start

### Option 1: Using Docker (Recommended)

Pull and run the official Docker image:

```bash
docker pull eth3rnit3/ferrum-mcp:latest
docker run -p 3000:3000 eth3rnit3/ferrum-mcp:latest
```

The server will be available at `http://0.0.0.0:3000`.

**Docker Hub:** [eth3rnit3/ferrum-mcp](https://hub.docker.com/r/eth3rnit3/ferrum-mcp)

### Option 2: Local Installation

```bash
git clone https://github.com/Eth3rnit3/FerrumMCP.git
cd FerrumMCP
bundle install
```

**Requirements:**
- Ruby 3.2 or higher
- Chrome/Chromium browser
- (Optional) whisper-cli for CAPTCHA solving
- (Optional) BotBrowser for anti-detection

### Start the Server

#### HTTP Transport (Default)

```bash
ruby server.rb
# or explicitly
ruby server.rb --transport http
```

The server will start on `http://0.0.0.0:3000` by default.

#### STDIO Transport

For MCP clients that require stdio protocol (e.g., Claude Desktop):

```bash
ruby server.rb --transport stdio
```

#### Help and Options

View all available options:

```bash
ruby server.rb --help
```

## Connect Your AI Assistant

### Claude Desktop

#### Using STDIO Transport (Recommended)

Add this configuration to your Claude Desktop config file:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "ferrum-mcp": {
      "command": "/path/to/ruby",
      "args": [
        "/path/to/ferrum-mcp/server.rb",
        "--transport",
        "stdio"
      ],
      "env": {
        "BROWSER_HEADLESS": "false"
      }
    }
  }
}
```

**Important**: Replace the paths with your actual paths:
- **Ruby path**: Find it with `which ruby` (e.g., `/Users/username/.rbenv/versions/3.3.5/bin/ruby`)
- **Server path**: Full path to your `server.rb` (e.g., `/Users/username/code/ferrum-mcp/server.rb`)

**Example with rbenv**:
```json
{
  "mcpServers": {
    "ferrum-mcp": {
      "command": "/Users/username/.rbenv/versions/3.3.5/bin/ruby",
      "args": [
        "/Users/username/code/ferrum-mcp/server.rb",
        "--transport",
        "stdio"
      ],
      "env": {
        "BROWSER_HEADLESS": "false"
      }
    }
  }
}
```

After updating the config, restart Claude Desktop.

#### Using HTTP Transport

Alternative setup using HTTP (requires manual server start):

```bash
# Start the server
ruby server.rb --transport http

# In another terminal, add to Claude
claude mcp add --transport http ferrum-mcp http://0.0.0.0:3000/mcp
```

### Other MCP Clients

For any MCP-compatible client:
- **HTTP Transport**: Configure pointing to `http://0.0.0.0:3000/mcp`
- **STDIO Transport**: Run `ruby server.rb --transport stdio` as a subprocess

## Usage Examples

Once connected, your AI assistant can perform browser automation tasks:

**Navigate to a website:**
> "Navigate to https://example.com"

**Extract information:**
> "Go to GitHub trending and tell me the top 3 repositories"

**Take screenshots:**
> "Take a screenshot of the current page"

**Interact with forms:**
> "Fill in the search box with 'AI tools' and submit the form"

**Execute JavaScript:**
> "Click the login button and wait for the page to load"

**Handle cookies:**
> "Accept the cookie banner on this website"

**Solve CAPTCHAs:**
> "Solve the audio CAPTCHA on this page"

## Session Management

FerrumMCP uses a session-based architecture. Each browser instance is managed as a session:

1. **Create a session** before performing browser operations
2. **Use the session ID** for all subsequent operations
3. **Close the session** when done (or let it auto-close after 30 minutes of inactivity)

Example workflow:
```
AI: Create a new browser session
AI: Navigate to https://example.com (using session ID)
AI: Take a screenshot (using session ID)
AI: Close the session
```

You can run multiple sessions concurrently with different configurations (different browsers, profiles, etc.).

## Next Steps

- Read the [API Reference](API_REFERENCE.md) to understand all available tools
- Check [Configuration Guide](CONFIGURATION.md) for advanced setup
- See [Troubleshooting](TROUBLESHOOTING.md) if you encounter issues
- Learn about [BotBrowser Integration](BOTBROWSER_INTEGRATION.md) for anti-detection
