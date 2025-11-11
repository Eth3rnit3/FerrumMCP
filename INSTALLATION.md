# Installation Guide

## Prerequisites

- Ruby 3.0 or higher
- Bundler
- BotBrowser binary
- BotBrowser profile file

## Step 1: Install Ruby Dependencies

```bash
bundle install
```

## Step 2: Download BotBrowser

1. Visit [BotBrowser Releases](https://github.com/botswin/BotBrowser/releases)
2. Download the appropriate binary for your platform:
   - **macOS**: `BotBrowser-Mac.zip`
   - **Windows**: `BotBrowser-Win.zip`
   - **Linux**: `BotBrowser-Linux.zip`

3. Extract the archive:

```bash
# Example for macOS
unzip BotBrowser-Mac.zip -d ./bin/botbrowser
```

## Step 3: Get a BotBrowser Profile

1. Download a demo profile from the [BotBrowser profiles directory](https://github.com/botswin/BotBrowser/tree/main/profiles)
2. Save it to `./config/profile.enc`

Alternatively, you can create your own profile using BotBrowser tools.

## Step 4: Configure Environment

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and set the paths:

```bash
# macOS example
BOTBROWSER_PATH=/Users/yourusername/code/ferrum-mcp/bin/botbrowser/BotBrowser.app/Contents/MacOS/BotBrowser
BOTBROWSER_PROFILE=/Users/yourusername/code/ferrum-mcp/config/profile.enc

# Linux example
BOTBROWSER_PATH=/home/yourusername/code/ferrum-mcp/bin/botbrowser/chrome
BOTBROWSER_PROFILE=/home/yourusername/code/ferrum-mcp/config/profile.enc

# Windows example (use forward slashes)
BOTBROWSER_PATH=C:/code/ferrum-mcp/bin/botbrowser/chrome.exe
BOTBROWSER_PROFILE=C:/code/ferrum-mcp/config/profile.enc

# Server configuration
MCP_SERVER_HOST=0.0.0.0
MCP_SERVER_PORT=3000

# Browser options
BROWSER_HEADLESS=false
BROWSER_TIMEOUT=60
```

## Step 5: Verify Installation

Check that the BotBrowser binary is executable:

```bash
# macOS/Linux
chmod +x bin/botbrowser/chrome

# Test the binary (it should start Chrome)
./bin/botbrowser/chrome --version
```

## Step 6: Start the Server

```bash
bundle exec ruby server.rb
```

You should see output like:

```
============================================================
Ferrum MCP Server v0.1.0
============================================================

Configuration:
  Browser: /path/to/botbrowser/chrome
  Profile: /path/to/profile.enc
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

## Troubleshooting

### "Browser path not found" error

Make sure the `BOTBROWSER_PATH` points to the actual Chrome executable:
- macOS: Inside the `.app/Contents/MacOS/` folder
- Linux: Usually just `chrome` in the extracted folder
- Windows: `chrome.exe` in the extracted folder

### "Profile not found" error

Ensure the `BOTBROWSER_PROFILE` path points to a valid `.enc` file. If you don't have a profile, the server will still work but without the anti-detection features.

### Port already in use

Change the `MCP_SERVER_PORT` to a different port number in your `.env` file.

### Browser fails to start

Try running with headless mode:
```bash
BROWSER_HEADLESS=true bundle exec ruby server.rb
```

## Next Steps

- Read [USAGE.md](USAGE.md) for how to use the tools
- See [API.md](API.md) for the complete API reference
- Check [EXAMPLES.md](EXAMPLES.md) for usage examples
