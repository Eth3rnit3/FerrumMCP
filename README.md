# FerrumMCP 🌐

[![CI](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/ci.yml/badge.svg)](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/ci.yml)
[![Release](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/release.yml/badge.svg)](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/release.yml)
[![Gem Version](https://img.shields.io/gem/v/ferrum-mcp?color=red&logo=rubygems)](https://rubygems.org/gems/ferrum-mcp)
[![Gem Downloads](https://img.shields.io/gem/dt/ferrum-mcp?logo=rubygems)](https://rubygems.org/gems/ferrum-mcp)
[![Docker](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/Eth3rnit3/FerrumMCP/actions/workflows/docker-publish.yml)
[![Docker Hub](https://img.shields.io/docker/pulls/eth3rnit3/ferrum-mcp.svg)](https://hub.docker.com/r/eth3rnit3/ferrum-mcp)
[![Ruby](https://img.shields.io/badge/ruby-3.2+-red.svg)](https://www.ruby-lang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> A browser automation server for the Model Context Protocol (MCP), enabling AI assistants to interact with web pages through a standardized interface.

---

## 🚀 Quick Links

| Documentation | Description |
|---------------|-------------|
| [**Getting Started**](docs/GETTING_STARTED.md) | Installation, setup, and first steps |
| [**Docker Deployment**](docs/DOCKER.md) | Complete Docker guide with Claude Desktop integration |
| [**API Reference**](docs/API_REFERENCE.md) | Complete documentation of all 41 tools |
| [**Configuration**](docs/CONFIGURATION.md) | Environment variables and advanced configuration |
| [**Troubleshooting**](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [**Deployment**](docs/DEPLOYMENT.md) | Production deployment guide |
| [**BotBrowser Integration**](docs/DOCKER_BOTBROWSER.md) | Anti-detection browser setup |

---

## 📖 Table of Contents

- [What is FerrumMCP?](#what-is-ferrummcp)
- [Features](#features)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Tools & Capabilities](#tools--capabilities)
- [Project Resources](#project-resources)
- [Contributing](#contributing)
- [License](#license)

---

## What is FerrumMCP?

FerrumMCP is a **browser automation server** that implements the **Model Context Protocol (MCP)** by Anthropic. It provides AI assistants with the ability to navigate websites, interact with elements, extract content, and perform complex browser automation tasks through a simple, standardized interface.

**Key Benefits:**
- 🤖 **AI-Native Design**: Purpose-built for AI assistants like Claude
- 🔄 **Session-Based**: Multiple concurrent browser sessions with isolated configurations
- 🌐 **Multi-Browser**: Support for Chrome, Edge, Brave, and BotBrowser
- 🧩 **Smart Automation**: Cookie banner detection and CAPTCHA solving (⚠️ experimental)
- 📦 **Easy Deployment**: Docker, systemd, or Kubernetes ready
- 🔌 **Dual Transport**: HTTP and STDIO for maximum compatibility

---

## Features

### Core Capabilities

✅ **Session Management**
- Create/manage multiple browser sessions
- Automatic cleanup (30min idle timeout)
- Custom browser configurations per session

✅ **Navigation**
- URL navigation with network idle detection
- Browser history (back/forward)
- Page refresh
- Tabs (open, list, switch, close) and viewport control
- Optional host allow/block lists

✅ **Agent-friendly page snapshot**
- `snapshot` lists interactive elements with stable refs (`ref:e12`) usable by every other tool
- Explicit waits: `wait_for_selector`, `wait_for_text`, `wait_for_network_idle`

✅ **Interaction**
- Click, hover, drag-and-drop
- Form filling with typing delays
- Keyboard input simulation
- **Smart cookie banner acceptance** (8 strategies, multi-language)
- **AI-powered CAPTCHA solving** (Whisper integration - ⚠️ experimental, under development)

✅ **Extraction**
- Text and HTML content extraction
- Screenshot capture (base64)
- Page metadata (title, URL)
- XPath-based text search

✅ **Advanced**
- JavaScript execution and evaluation
- Cookie management (get/set/clear)
- Shadow DOM querying
- Element attribute retrieval

### Enterprise Features

🦾 **BotBrowser Integration**
- Anti-detection browser automation
- Fingerprint management with encrypted profiles
- **Note**: Requires valid trial/premium profiles (demo profiles cause session instability)

🔒 **Security** (v1.0+)
- Session limits
- Rate limiting
- Health check endpoint
- Non-root Docker user

📊 **Observability**
- File-based logging
- Health checks
- Metrics endpoint (planned)

---

## Quick Start

### Option 1: Docker (Recommended)

**Standard Image** (Chromium only):
```bash
docker pull eth3rnit3/ferrum-mcp:latest
docker run --security-opt seccomp=unconfined -p 3000:3000 eth3rnit3/ferrum-mcp:latest
```

**BotBrowser Image** (Anti-detection):
```bash
docker pull eth3rnit3/ferrum-mcp:botbrowser
docker run --security-opt seccomp=unconfined -p 3000:3000 \
  -v /path/to/bot_profiles:/profiles:ro \
  -e "BROWSER_BOTBROWSER=botbrowser:/opt/botbrowser/chrome:BotBrowser:Anti-detection browser" \
  -e "BOT_PROFILE_MACOS_1=/profiles/profile_1.enc:Profile 1:Trial profile 1" \
  eth3rnit3/ferrum-mcp:botbrowser
```
### Option 2: Gem Installation

```bash
gem install ferrum-mcp
ferrum-mcp start
```

### Option 3: From Source

```bash
git clone https://github.com/Eth3rnit3/FerrumMCP.git
cd FerrumMCP
bundle install
ruby bin/ferrum-mcp
```

**➡️ [Full installation guide](docs/GETTING_STARTED.md)**

---

## Documentation

### Getting Started

| Guide | Description |
|-------|-------------|
| [**Installation**](docs/GETTING_STARTED.md#quick-start) | Docker, gem, and source installation |
| [**Claude Desktop Setup**](docs/GETTING_STARTED.md#claude-desktop) | Integrate with Claude Desktop (STDIO) |
| [**First Session**](docs/GETTING_STARTED.md#usage-examples) | Create your first browser automation |

### Configuration

| Topic | Link |
|-------|------|
| **Environment Variables** | [Configuration Guide](docs/CONFIGURATION.md) |
| **Multi-Browser Setup** | [Multi-Browser Config](docs/CONFIGURATION.md#multi-browser-configuration) |
| **BotBrowser Integration** | [BotBrowser Guide](docs/DOCKER_BOTBROWSER.md) |
| **Resource Discovery** | [Resource Config](docs/CONFIGURATION.md#resource-discovery) |

### API Documentation

| Resource | Description |
|----------|-------------|
| [**API Reference**](docs/API_REFERENCE.md) | Complete tool documentation with examples |
| [**Session Management**](docs/API_REFERENCE.md#session-management) | Create, list, and manage browser sessions |
| [**Navigation Tools**](docs/API_REFERENCE.md#navigation-tools) | URL navigation and history |
| [**Interaction Tools**](docs/API_REFERENCE.md#interaction-tools) | Click, fill forms, solve CAPTCHAs |
| [**Extraction Tools**](docs/API_REFERENCE.md#extraction-tools) | Get content, screenshots, metadata |
| [**Advanced Tools**](docs/API_REFERENCE.md#advanced-tools) | JavaScript, cookies, Shadow DOM |

### Operations

| Guide | Description |
|-------|-------------|
| [**Troubleshooting**](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [**Deployment**](docs/DEPLOYMENT.md) | Docker, K8s, systemd deployment |
| [**Migration**](docs/MIGRATION.md) | Upgrade between versions |

---

## Tools & Capabilities

FerrumMCP provides **41 browser automation tools** organized into 8 categories:

### 1. Session Management (4 tools)
- `create_session` - Create browser sessions with custom config
- `list_sessions` - List all active sessions
- `get_session_info` - Get detailed session information
- `close_session` - Manually close a session

### 2. Navigation (4 tools)
- `navigate` - Navigate to URLs
- `go_back` - Browser back button
- `go_forward` - Browser forward button
- `refresh` - Reload current page

### 3. Interaction (10 tools)
- `click` - Click elements (CSS, XPath or snapshot ref)
- `fill_form` - Fill form fields
- `press_key` - Keyboard input
- `hover` - Mouse hover
- `drag_and_drop` - Drag elements
- `scroll` - Scroll the page, a container, or an element into view
- `select_option` - Pick options in `<select>` elements
- `upload_file` - Attach files to file inputs
- `accept_cookies` - **Smart cookie banner detection** (8 strategies)
- `solve_captcha` - **AI-powered CAPTCHA solving** (⚠️ experimental, under development)

### 4. Extraction (7 tools)
- `snapshot` - **Compact page snapshot with stable element refs**
- `get_text` - Extract text content
- `get_html` - Get HTML content
- `screenshot` - Capture screenshots
- `get_title` - Get page title
- `get_url` - Get current URL
- `find_by_text` - XPath text search

### 5. Waiting (3 tools)
- `wait_for_selector` - Wait for an element to be visible/hidden/attached/detached
- `wait_for_text` - Wait for text to appear
- `wait_for_network_idle` - Wait for pending requests to finish

### 6. Tabs & Viewport (5 tools)
- `list_tabs`, `new_tab`, `switch_tab`, `close_tab` - Tab management
- `set_viewport` - Viewport size and mobile emulation

### 7. Advanced (7 tools)
- `execute_script` - Run JavaScript
- `evaluate_js` - Evaluate JavaScript with return value
- `get_cookies` - Get browser cookies
- `set_cookie` - Set cookies
- `clear_cookies` - Clear cookies
- `get_attribute` - Get element attributes
- `query_shadow_dom` - Interact with Shadow DOM

### 8. MCP Resources (7 resources)
- `ferrum://browsers` - Discover configured browsers
- `ferrum://user-profiles` - Discover Chrome profiles
- `ferrum://bot-profiles` - Discover BotBrowser profiles
- `ferrum://capabilities` - Server capabilities

**➡️ [Complete API Reference](docs/API_REFERENCE.md)**

---

## Project Resources

### Development

| Resource | Link |
|----------|------|
| **Contributing Guide** | [CONTRIBUTING.md](CONTRIBUTING.md) |
| **Security Policy** | [SECURITY.md](SECURITY.md) |
| **Changelog** | [CHANGELOG.md](CHANGELOG.md) |
| **AI Development Guide** | [CLAUDE.md](CLAUDE.md) |

### Community

| Platform | Link |
|----------|------|
| **GitHub Issues** | [Report bugs](https://github.com/Eth3rnit3/FerrumMCP/issues) |
| **GitHub Discussions** | [Ask questions](https://github.com/Eth3rnit3/FerrumMCP/discussions) |
| **Docker Hub** | [eth3rnit3/ferrum-mcp](https://hub.docker.com/r/eth3rnit3/ferrum-mcp) |

### Links

| Resource | URL |
|----------|-----|
| **Repository** | https://github.com/Eth3rnit3/FerrumMCP |
| **Documentation** | https://github.com/Eth3rnit3/FerrumMCP/tree/main/docs |
| **Releases** | https://github.com/Eth3rnit3/FerrumMCP/releases |
| **RubyGems** | https://rubygems.org/gems/ferrum-mcp |

---

## Requirements

### System Requirements
- **Ruby**: 3.2 or higher
- **Browser**: Chrome, Chromium, Edge, or Brave
- **OS**: Linux, macOS, or Windows

### Optional Dependencies
- **whisper-cli**: For CAPTCHA solving
- **BotBrowser**: For anti-detection automation
- **Docker**: For containerized deployment

---

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

**Quick contribution checklist:**
- 📖 Read [CONTRIBUTING.md](CONTRIBUTING.md)
- 🐛 Use issue templates for bugs
- ✨ Use feature request template
- ✅ Run tests: `bundle exec rspec`
- 📝 Update documentation
- 🎨 Follow RuboCop style

---

## Security

For security vulnerabilities, please email [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com). See [SECURITY.md](SECURITY.md) for our security policy.

---

## License

FerrumMCP is released under the [MIT License](LICENSE).

---

## Credits

Built with:
- [Ferrum](https://github.com/rubycdp/ferrum) - Ruby Chrome DevTools Protocol
- [Model Context Protocol](https://github.com/anthropics/mcp) by Anthropic
- [Whisper](https://github.com/ggerganov/whisper.cpp) for CAPTCHA solving
- [BotBrowser](https://botbrowser.com) for anti-detection (optional)

---

## Support

- 📚 **Documentation**: [docs/](docs/)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Eth3rnit3/FerrumMCP/discussions)
- 🐛 **Issues**: [GitHub Issues](https://github.com/Eth3rnit3/FerrumMCP/issues)
- 📧 **Email**: [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com)

---

<p align="center">
  <strong>Made with ❤️ by <a href="https://github.com/Eth3rnit3">Eth3rnit3</a></strong>
</p>

<p align="center">
  <a href="#-quick-links">Back to Top</a>
</p>
