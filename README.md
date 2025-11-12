# FerrumMCP 🌐

A browser automation server for the Model Context Protocol (MCP), enabling AI assistants to interact with web pages through a standardized interface.

## What is FerrumMCP?

FerrumMCP provides AI assistants with browser automation capabilities via the MCP protocol. It allows your AI to navigate websites, interact with elements, extract content, and take screenshots - all through a simple HTTP interface.

**Key features:**
- 🌐 Full browser automation (navigate, click, fill forms, etc.)
- 📸 Screenshot capture (full page or specific elements)
- 🔍 Content extraction (text, HTML, attributes)
- 🍪 Cookie management
- ⚡ JavaScript execution
- 🔄 Wait conditions for dynamic content

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

### Start the Server

#### HTTP Transport (Default)

```bash
ruby server.rb
# or explicitly
ruby server.rb --transport http
```

The server will start on `http://0.0.0.0:3000` by default.

#### STDIO Transport

For MCP clients that require stdio protocol:

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

Add this configuration to your Claude Desktop config file (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

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

## Available Tools

FerrumMCP provides 23 browser automation tools organized in 5 categories:

- **Navigation**: navigate, go back/forward, refresh
- **Interaction**: click, fill forms, press keys, hover
- **Extraction**: get text, HTML, screenshots, page info
- **Waiting**: wait for elements, navigation, delays
- **Advanced**: execute JavaScript, manage cookies, get attributes

## Configuration

Environment variables:
- `PORT` - Server port (default: 3000)
- `HOST` - Server host (default: 0.0.0.0)
- `BROWSER_HEADLESS` - Run browser in headless mode (default: true)
- `LOG_LEVEL` - Logging level: debug, info, warn, error (default: info)

## Requirements

- Ruby 3.2 or higher
- Chrome/Chromium browser

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.
