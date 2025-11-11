# Quick Start Guide

Get up and running with Ferrum MCP Server in 5 minutes!

## 1. Install Dependencies

```bash
bundle install
```

## 2. Download BotBrowser

### macOS
```bash
cd bin
curl -L -O https://github.com/botswin/BotBrowser/releases/latest/download/BotBrowser-Mac.zip
unzip BotBrowser-Mac.zip
cd ..
```

### Linux
```bash
cd bin
curl -L -O https://github.com/botswin/BotBrowser/releases/latest/download/BotBrowser-Linux.zip
unzip BotBrowser-Linux.zip
cd ..
```

### Windows (PowerShell)
```powershell
cd bin
curl.exe -L -O https://github.com/botswin/BotBrowser/releases/latest/download/BotBrowser-Win.zip
Expand-Archive BotBrowser-Win.zip
cd ..
```

## 3. Configure Environment

```bash
# Copy example config
cp .env.example .env

# Edit .env with your paths
# Example for macOS:
# BOTBROWSER_PATH=/Users/yourname/code/ferrum-mcp/bin/BotBrowser.app/Contents/MacOS/BotBrowser

# Check configuration
bundle exec rake check_env
```

## 4. Start Server

```bash
bundle exec ruby server.rb
```

You should see:
```
============================================================
Ferrum MCP Server v0.1.0
============================================================

Configuration:
  Browser: /path/to/botbrowser/chrome
  Profile: none
  Headless: false
  Timeout: 60s

Server:
  Host: 0.0.0.0
  Port: 3000
  MCP Endpoint: http://0.0.0.0:3000/mcp

============================================================
Press Ctrl+C to stop
============================================================
```

## 5. Test It

Open a new terminal and test:

```bash
# Health check
curl http://localhost:3000/health

# Navigate to a website
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://example.com"}
    },
    "id": 1
  }'

# Get page title
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_title",
      "arguments": {}
    },
    "id": 2
  }'
```

## 6. Connect with Claude Desktop

Add to your Claude config (`~/.config/claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "ferrum-browser": {
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

Restart Claude Desktop and you'll have browser automation tools!

## Common Commands

```bash
# Check environment
bundle exec rake check_env

# List all tools
bundle exec rake list_tools

# Run linter
bundle exec rake rubocop

# Start server
bundle exec ruby server.rb
```

## Troubleshooting

**"Browser path not found"**
- Make sure BOTBROWSER_PATH in `.env` points to the actual Chrome executable
- On macOS, it's inside the `.app` bundle: `BotBrowser.app/Contents/MacOS/BotBrowser`

**"Port already in use"**
- Change `MCP_SERVER_PORT` in `.env` to a different port like 3001

**Browser won't start**
- Try headless mode: `BROWSER_HEADLESS=true` in `.env`
- Check BotBrowser is executable: `chmod +x /path/to/chrome`

## Next Steps

- Read [USAGE.md](USAGE.md) for detailed usage
- Check [API.md](API.md) for complete API reference
- See [EXAMPLES.md](EXAMPLES.md) for real-world examples
- Review [INSTALLATION.md](INSTALLATION.md) for advanced setup

## Need Help?

- Check the logs - the server prints detailed logs
- Try running with `LOG_LEVEL=debug` in `.env`
- Open an issue on GitHub
