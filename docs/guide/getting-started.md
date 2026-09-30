# Getting Started

FerrumMCP is an MCP server that drives a real Chrome for AI assistants. This guide gets it running and connected to Claude.

## Requirements

- **Gem / source**: Ruby 3.2+ and Chrome or Chromium
- **Docker**: nothing else (Chromium is in the image)
- **Optional**: `whisper-cli` (whisper.cpp), plus `ffmpeg` (recommended), only to solve reCAPTCHA audio challenges. Turnstile and hCaptcha don't need them.

## Install

**Gem** (recommended):

```bash
gem install ferrum-mcp
ferrum-mcp start                       # HTTP server on http://localhost:3000/mcp
ferrum-mcp start --transport stdio     # STDIO, for MCP clients that spawn the server
```

**Docker** (headless only):

```bash
docker run --rm --security-opt seccomp=unconfined -p 3000:3000 eth3rnit3/ferrum-mcp:latest
```

**From source**:

```bash
git clone https://github.com/Eth3rnit3/FerrumMCP.git && cd FerrumMCP
bundle install
bundle exec ruby bin/ferrum-mcp start --transport stdio
```

Check it's up (HTTP): `curl http://localhost:3000/health` → `{"status":"ok"}`.

## Connect an MCP client

### Claude Code

```bash
claude mcp add ferrum -- ferrum-mcp start --transport stdio
# or, against a running HTTP server:
claude mcp add --transport http ferrum http://localhost:3000/mcp
```

### Claude Desktop

Edit `claude_desktop_config.json` (macOS: `~/Library/Application Support/Claude/`, Windows: `%APPDATA%\Claude\`, Linux: `~/.config/Claude/`), then restart Claude Desktop.

```json
{
  "mcpServers": {
    "ferrum": {
      "command": "ferrum-mcp",
      "args": ["start", "--transport", "stdio"],
      "env": {
        "BROWSER_HEADLESS": "false",
        "LOG_FILE": "/Users/you/ferrum_mcp.log"
      }
    }
  }
}
```

Put settings in the `env` block: Claude Desktop does not start the server in your project directory, so a `.env` file there is not read, and the default log path (`./logs/ferrum_mcp.log`) would be relative to an unknown directory. Use an absolute `LOG_FILE`, or `stderr` to see logs in Claude Desktop's MCP log. If `ferrum-mcp` is not on the PATH Claude Desktop sees (rbenv, asdf), use the absolute path of the executable (`which ferrum-mcp`).

With Docker instead:

```json
{
  "mcpServers": {
    "ferrum": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--security-opt", "seccomp=unconfined",
               "eth3rnit3/ferrum-mcp:latest", "bin/ferrum-mcp", "start", "--transport", "stdio"]
    }
  }
}
```

## First session

Every browser tool needs a `session_id`. Ask Claude something like:

- "Create a browser session (not headless) and open https://example.com"
- "Take a snapshot of the page and click the 'More information' link"
- "Fill the login form with user `demo` and submit it"
- "Accept the cookie banner, then take a screenshot"
- "Run `document.title` in the page"
- "Solve the CAPTCHA on this page"

The usual loop is `create_session` → `navigate` → `snapshot` (lists interactive elements with refs such as `ref:e12`) → `click` / `fill_form` with those refs → `close_session`. Sessions close by themselves after 30 minutes idle.

## Next steps

- [API reference](/reference/): every tool and its parameters
- [Configuration](/guide/configuration): browsers, profiles, security, Whisper
- [Docker](/deployment/docker) and [BotBrowser in Docker](/deployment/botbrowser-docker)
- [Troubleshooting](/guide/troubleshooting)
