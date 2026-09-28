# FerrumMCP

[![CI](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/ci.yml/badge.svg)](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/ferrum-mcp?color=red&logo=rubygems)](https://rubygems.org/gems/ferrum-mcp)
[![Docker Hub](https://img.shields.io/docker/pulls/eth3rnit3/ferrum-mcp.svg)](https://hub.docker.com/r/eth3rnit3/ferrum-mcp)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A [Model Context Protocol](https://modelcontextprotocol.io) server that gives AI assistants a real Chrome: navigate, click, fill forms, read pages, take screenshots, and get past cookie banners and CAPTCHAs. Built on [Ferrum](https://github.com/rubycdp/ferrum).

- **40 tools**, agent-friendly: `snapshot` lists interactive elements with stable refs (`ref:e12`) usable by every other tool
- **Sessions**: several browsers in parallel, each with its own browser, profile and flags
- **Looks like a stock Chrome**: no automation flags, WebGL on, regular user agent even headless
- **STDIO or HTTP** transport, gem or Docker

## Quick start

```bash
gem install ferrum-mcp          # needs Ruby 3.2+ and Chrome/Chromium
```

Add it to your MCP client:

```bash
# Claude Code
claude mcp add ferrum -- ferrum-mcp start --transport stdio
```

Claude Desktop (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "ferrum": { "command": "ferrum-mcp", "args": ["start", "--transport", "stdio"] }
  }
}
```

Or run the HTTP server (endpoint `http://localhost:3000/mcp`, health check on `/health`):

```bash
ferrum-mcp start                                   # from the gem
docker run --security-opt seccomp=unconfined -p 3000:3000 eth3rnit3/ferrum-mcp:latest
```

Every browser tool takes a `session_id`: call `create_session` first (`headless: false` to watch it), then `navigate`, `snapshot`, `click`… Sessions close after 30 minutes idle.

## Tools

| Category | Tools |
|---|---|
| Sessions | `create_session` `list_sessions` `get_session_info` `close_session` |
| Navigation | `navigate` `go_back` `go_forward` `refresh` |
| Interaction | `click` `fill_form` `press_key` `hover` `drag_and_drop` `scroll` `select_option` `upload_file` `accept_cookies` `solve_captcha` |
| Extraction | `snapshot` `get_text` `get_html` `screenshot` `get_title` `get_url` `find_by_text` |
| Waiting | `wait_for_selector` `wait_for_text` `wait_for_network_idle` |
| Tabs & viewport | `list_tabs` `new_tab` `switch_tab` `close_tab` `set_viewport` |
| Advanced | `execute_script` `evaluate_js` `get_cookies` `set_cookie` `clear_cookies` `get_attribute` `query_shadow_dom` |

Selectors accept CSS, XPath (`//…` or `xpath:…`) and snapshot refs. MCP resources (`ferrum://browsers`, `ferrum://user-profiles`, `ferrum://bot-profiles`, `ferrum://capabilities`) describe what the server is configured with. Details: [API reference](docs/API_REFERENCE.md).

## CAPTCHAs

`solve_captcha` detects the widget on the page, solves it, and returns the token. When it can't, it says why instead of pretending: `blocked`, `distrusted`, `challenge_required` or `failed`.

| Provider | What to expect |
|---|---|
| Cloudflare Turnstile and "Just a moment…" pages | Passed with a human-like click, headful and headless |
| reCAPTCHA v2 | Solved through the audio challenge with local [whisper.cpp](https://github.com/ggerganov/whisper.cpp) **when Google serves a real audio**. Anonymous sessions usually get Google's decoy audio instead: the tool recognises it and stops (`distrusted`) rather than burning the IP. A long-lived browser profile and a residential IP help a lot. |
| hCaptcha | Checkbox only; a visual challenge returns `challenge_required` with a screenshot |

reCAPTCHA needs `whisper-cli` (`brew install whisper-cpp`), `ffmpeg` is recommended; models download on first use. See [Whisper configuration](docs/CONFIGURATION.md#whisper-configuration-captcha-solving).

## Configuration

Everything is optional and set through environment variables (or a `.env` file):

```bash
BROWSER_HEADLESS=false                                   # default for new sessions
BROWSER_CHROME=chrome:/path/to/chrome:Chrome:My Chrome   # extra browsers, picked with browser_id
USER_PROFILE_WORK=/path/to/profile:Work:Logged-in profile  # persistent profiles, user_profile_id
ALLOWED_HOSTS=*.example.com                              # navigation policy (also BLOCKED_HOSTS)
API_KEY_ENABLED=true  API_KEY=...                        # bearer auth for the HTTP transport
LOG_FILE=stderr                                          # default: ./logs/ferrum_mcp.log
```

[BotBrowser](https://botbrowser.com) (anti-detection Chromium, licensed profiles) is supported as just another browser. Full list: [configuration guide](docs/CONFIGURATION.md).

## Documentation

[Getting started](docs/GETTING_STARTED.md) · [API reference](docs/API_REFERENCE.md) · [Configuration](docs/CONFIGURATION.md) · [Docker](docs/DOCKER.md) · [BotBrowser in Docker](docs/DOCKER_BOTBROWSER.md) · [Deployment](docs/DEPLOYMENT.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Changelog](CHANGELOG.md)

## Development

```bash
git clone https://github.com/Eth3rnit3/FerrumMCP.git && cd FerrumMCP
bundle install
ruby bin/ferrum-mcp --transport stdio   # run from source
rake test:unit                          # fast, no Chrome
bundle exec rspec                       # full suite, drives a headless Chrome
bundle exec rubocop
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md) (architecture notes). Security issues: [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) · Made by [Eth3rnit3](https://github.com/Eth3rnit3)
