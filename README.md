# Ferrum MCP Server

A Model Context Protocol (MCP) server that provides web automation capabilities through Ferrum, with optional BotBrowser integration for advanced anti-detection features. This enables AI agents to interact with web pages seamlessly.

## 🚀 Quick Start

New to Ferrum MCP? Check out the [Quick Start Guide](QUICKSTART.md) to get running in 5 minutes!

## Features

- **Full Browser Automation**: Navigate, click, fill forms, and interact with web pages
- **Content Extraction**: Get text, HTML, screenshots, and page metadata
- **Optional Anti-Detection**: Enhanced stealth with BotBrowser integration
- **Advanced Capabilities**: Execute JavaScript, manage cookies, wait for elements
- **HTTP/SSE Transport**: Remote server accessible via HTTP with Server-Sent Events
- **Flexible Browser Support**: Works with system Chrome/Chromium or custom browsers

## 📚 Documentation

- [Quick Start Guide](QUICKSTART.md) - Get started in 5 minutes
- [Installation Guide](INSTALLATION.md) - Detailed installation instructions
- [Usage Guide](USAGE.md) - How to use the server and tools
- [API Reference](API.md) - Complete API documentation
- [Examples](EXAMPLES.md) - Real-world usage examples

## Prerequisites

- Ruby 3.0 or higher
- Chrome or Chromium browser (usually already installed)
- **Optional but recommended**: [BotBrowser](https://github.com/botswin/BotBrowser) for advanced anti-detection features

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd ferrum-mcp
```

2. Install dependencies:
```bash
bundle install
```

3. **(Optional)** For enhanced anti-detection, download BotBrowser:
   - Visit https://github.com/botswin/BotBrowser/releases
   - Download the binary for your platform
   - Extract to a known location (e.g., `./bin/botbrowser`)
   - Get a profile file and save it as `./config/profile.enc`

## Configuration

The server works out of the box with your system's Chrome/Chromium browser. For advanced features, create a `.env` file:

```bash
# Option 1: Use system Chrome/Chromium (default - no config needed)
# Just leave BROWSER_PATH unset

# Option 2: Use custom Chrome/Chromium path
# BROWSER_PATH=/path/to/chrome

# Option 3: Use BotBrowser for anti-detection (recommended for production)
# BROWSER_PATH=/path/to/botbrowser/chrome
# BOTBROWSER_PROFILE=/path/to/profile.enc

# Server configuration
MCP_SERVER_HOST=0.0.0.0
MCP_SERVER_PORT=3000
```

**Note**: For production use or when you need maximum stealth capabilities, we recommend using [BotBrowser](https://github.com/botswin/BotBrowser) which provides advanced anti-detection features and consistent fingerprints across platforms.

## Usage

### Starting the Server

```bash
bundle exec ruby server.rb
```

The server will start and automatically detect your Chrome/Chromium browser.

### Connecting from Claude Desktop

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "ferrum-browser": {
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

## Available Tools

### Navigation
- `navigate` - Navigate to a URL
- `go_back` - Go back in browser history
- `go_forward` - Go forward in browser history
- `refresh` - Refresh the current page

### Interaction
- `click` - Click an element
- `fill_form` - Fill form fields
- `press_key` - Press keyboard keys
- `hover` - Hover over an element

### Content Extraction
- `get_text` - Extract text from elements
- `get_html` - Get page HTML
- `screenshot` - Take a screenshot
- `get_title` - Get page title
- `get_url` - Get current URL

### Waiting & Timing
- `wait_for_element` - Wait for element to appear
- `wait_for_navigation` - Wait for page navigation
- `wait` - Simple delay

### Advanced
- `execute_script` - Execute JavaScript
- `evaluate_js` - Evaluate JavaScript and return result
- `get_cookies` - Get browser cookies
- `set_cookie` - Set a cookie
- `clear_cookies` - Clear cookies
- `get_attribute` - Get element attributes

**Total: 22 tools** organized in 5 categories

## Browser Modes

### Standard Mode (Default)
Uses your system's Chrome/Chromium browser. Perfect for:
- Development and testing
- Basic automation tasks
- Getting started quickly

### BotBrowser Mode (Optional)
Uses BotBrowser for enhanced capabilities. Recommended for:
- Production environments
- Web scraping at scale
- Sites with anti-bot detection
- Maximum stealth requirements

To enable BotBrowser mode, set `BROWSER_PATH` and `BOTBROWSER_PROFILE` in your `.env` file.

## Architecture

```
ferrum-mcp/
├── lib/
│   ├── ferrum_mcp/
│   │   ├── server.rb          # MCP server implementation
│   │   ├── browser_manager.rb # Browser lifecycle management
│   │   ├── tools/              # Tool implementations
│   │   │   ├── navigation_tools.rb
│   │   │   ├── interaction_tools.rb
│   │   │   ├── extraction_tools.rb
│   │   │   ├── waiting_tools.rb
│   │   │   └── advanced_tools.rb
│   │   └── transport/
│   │       └── http_server.rb    # HTTP+SSE transport
│   └── ferrum_mcp.rb
├── config/
│   └── profile.enc            # BotBrowser profile (optional)
├── server.rb                   # Server entry point
└── [Documentation files]
```

## Development

Run tests:
```bash
bundle exec rspec
```

Run linter:
```bash
bundle exec rubocop
```

Check configuration:
```bash
bundle exec rake check_env
```

List all tools:
```bash
bundle exec rake list_tools
```

## Security & Responsible Use

This tool is designed for:
- Authorized testing and development
- Educational purposes
- Web scraping with permission
- Automated testing of your own applications

**Important**: Always obtain proper authorization before automating interactions with websites. Respect robots.txt and terms of service.

When using BotBrowser, please review their DISCLAIMER.md and RESPONSIBLE_USE.md for additional legal considerations.

## License

MIT

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Support

- Check [QUICKSTART.md](QUICKSTART.md) for common setup issues
- Review [USAGE.md](USAGE.md) for detailed usage instructions
- See [EXAMPLES.md](EXAMPLES.md) for real-world examples
- Open GitHub issues for bugs or feature requests
