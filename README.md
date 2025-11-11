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

### Installation

```bash
git clone https://github.com/Eth3rnit3/FerrumMCP.git
cd FerrumMCP
bundle install
```

### Start the Server

```bash
ruby server.rb
```

The server will start on `http://0.0.0.0:3000` by default.

## Connect Your AI Assistant

### Claude Desktop

Add FerrumMCP to your Claude configuration:

```bash
claude mcp add --transport http ferrum-mcp http://0.0.0.0:3000/mcp
```

### Other MCP Clients

For any MCP-compatible client, configure an HTTP transport pointing to:
```
http://0.0.0.0:3000/mcp
```

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
