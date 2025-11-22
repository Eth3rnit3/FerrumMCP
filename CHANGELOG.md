# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation structure in `docs/` directory
- API reference with all 27+ tools documented
- Configuration guide for multi-browser and multi-profile setups
- Getting started guide with detailed setup instructions
- CHANGELOG.md for version tracking
- SECURITY.md with responsible disclosure policy
- CONTRIBUTING.md with contribution guidelines
- GitHub issue and PR templates
- Gemspec for RubyGems packaging
- CLI command structure with `ServerRunner` and `CommandHandler` classes
- Comprehensive help text with usage examples
- `wait_for_selector` tool for explicit element waiting
- `wait_for_text` tool for text-based waiting

### Changed
- README.md restructured as table of contents
- Documentation reorganized into dedicated `docs/` folder
- **CLI architecture refactored** with clear separation of concerns
  - Created `ServerRunner` class for server lifecycle management
  - Created `CommandHandler` class for command dispatching
  - Simplified `bin/ferrum-mcp` to minimal entry point (reduced from ~131 to ~67 lines)
  - Removed `server.rb` to eliminate duplication
  - Updated command format: `ferrum-mcp [COMMAND] [OPTIONS]` (e.g., `ferrum-mcp help`, `ferrum-mcp version`, `ferrum-mcp start`)
- Test infrastructure improved with `SessionManager` integration
  - All tool tests now use `SessionManager#with_session` pattern
  - Consistent session management across test suite
  - Better test isolation and cleanup
- Updated `server_options_spec.rb` to match new CLI structure

### Fixed
- BaseTool `find_element` now uses Ferrum's native wait instead of manual polling with sleep
- Navigation tools properly wait for network idle after page transitions
- XSS protection in HoverTool using proper JavaScript escaping with `inspect`
- XPath injection protection in FindByTextTool with proper quote escaping
- Stale element retry logic in ClickTool and FillFormTool
- EvaluateJSTool now properly returns JavaScript evaluation results
- BrowserManager crash detection and graceful error handling
- PressKey tool no longer duplicates characters when pressing special keys
- ClickTool supports force clicking hidden elements with `force: true` parameter
- DragAndDropTool supports both target elements and coordinates
- GetTextTool supports XPath selectors with `xpath:` prefix
- QueryShadowDOMTool for interacting with Shadow DOM elements (click, get_text, get_html, get_attribute)

### Security
- Documented security model and trust assumptions
- Added session limit recommendations
- Implemented XSS and XPath injection protections in multiple tools

## [0.1.0] - 2024-11-22

Initial release of FerrumMCP - Browser automation server implementing the Model Context Protocol.

### Added

#### Core Features
- **Session-based architecture** with automatic cleanup (30min idle timeout)
- **Multi-browser support** via structured environment variables
- **Multi-profile support** for Chrome user profiles and BotBrowser fingerprints
- **MCP Resource discovery** for AI agents to introspect available configurations
- **Dual transport support** (HTTP via Puma and STDIO for Claude Desktop)
- **Thread-safe session management** with mutex-protected operations

#### Session Management Tools (4 tools)
- `create_session` - Create browser sessions with custom configuration
- `list_sessions` - List all active browser sessions
- `get_session_info` - Get detailed information about a session
- `close_session` - Manually close a browser session

#### Navigation Tools (4 tools)
- `navigate` - Navigate to URLs with network idle waiting
- `go_back` - Navigate back in browser history
- `go_forward` - Navigate forward in browser history
- `refresh` - Reload current page

#### Interaction Tools (7 tools)
- `click` - Click elements with retry logic for stale elements
- `fill_form` - Fill form fields with typing delays
- `press_key` - Simulate keyboard input (Enter, Tab, Escape, etc.)
- `hover` - Hover over elements with JavaScript fallback
- `drag_and_drop` - Drag elements with smooth animations
- `accept_cookies` - **Smart cookie banner detection and acceptance**
  - 8 detection strategies (ID, class, text, ARIA, buttons, shadows, iframes, common selectors)
  - Multi-language support (English, French, German, Spanish, Italian, Portuguese, Dutch, Swedish, Norwegian, Danish, Finnish)
  - Customizable selectors and texts
- `solve_captcha` - **AI-powered CAPTCHA solving**
  - Audio CAPTCHA support with Whisper speech recognition
  - Automatic iframe detection and switching
  - Model selection (tiny, base, small, medium)
  - Automatic model download and caching

#### Extraction Tools (6 tools)
- `get_text` - Extract text from elements
- `get_html` - Get HTML content (full page or element)
- `screenshot` - Capture screenshots with base64 encoding and auto-resize
- `get_title` - Get current page title
- `get_url` - Get current page URL
- `find_by_text` - XPath-based text search with visibility filtering

#### Advanced Tools (9 tools)
- `execute_script` - Execute JavaScript without return value
- `evaluate_js` - Evaluate JavaScript with return value
- `get_cookies` - Get all or domain-filtered cookies
- `set_cookie` - Set cookies with all attributes (domain, path, secure, httpOnly, sameSite)
- `clear_cookies` - Clear all or domain-filtered cookies
- `get_attribute` - Get element attributes
- `query_shadow_dom` - Interact with Shadow DOM elements

#### MCP Resources (7 resources)
- `ferrum://browsers` - List all configured browsers
- `ferrum://browsers/{id}` - Browser details with usage examples
- `ferrum://user-profiles` - List Chrome user profiles
- `ferrum://user-profiles/{id}` - User profile details
- `ferrum://bot-profiles` - List BotBrowser profiles with anti-detection features
- `ferrum://bot-profiles/{id}` - Bot profile details
- `ferrum://capabilities` - Server capabilities and feature flags

#### BotBrowser Integration
- **Optional BotBrowser support** for anti-detection browser automation
- Profile encryption support (`.enc` files)
- Graceful fallback when BotBrowser not available
- Configuration via `BROWSER_BOTBROWSER` and `BOT_PROFILE_*` environment variables
- See [docs/BOTBROWSER_INTEGRATION.md](docs/BOTBROWSER_INTEGRATION.md) for details

#### Configuration System
- **Multi-browser configuration**: `BROWSER_<ID>=type:path:name:description`
- **User profile configuration**: `USER_PROFILE_<ID>=path:name:description`
- **Bot profile configuration**: `BOT_PROFILE_<ID>=path:name:description`
- Legacy configuration support (`BROWSER_PATH`, `BOTBROWSER_PATH`, `BOTBROWSER_PROFILE`)
- Environment variable validation at startup
- Configuration discovery through MCP Resources

#### Infrastructure
- **Docker support** with multi-platform builds (amd64, arm64)
- **GitHub Actions CI/CD**:
  - RuboCop linting with GitHub annotations
  - Zeitwerk eager loading validation
  - RSpec tests on Ruby 3.2 and 3.3
  - Coverage reporting (79% line, 55% branch)
  - Automatic Docker image publishing
- **Comprehensive test suite** with 79% line coverage
  - Unit tests for all tools
  - Integration tests for multi-browser scenarios
  - Test fixtures with WEBrick server
  - SimpleCov coverage reporting
- **File-only logging** to `logs/ferrum_mcp.log` (STDIO transport compatible)
- **Zeitwerk autoloading** with custom inflections (MCP, HTML, URL, JS)

#### Documentation
- Comprehensive README with quick start guides
- CLAUDE.md for AI assistant development guidance
- BOTBROWSER_INTEGRATION.md for anti-detection setup
- .env.example with all configuration options
- Inline code documentation for complex logic

### Technical Details

#### Dependencies
- Ruby 3.2+ required
- Ferrum 0.17.1 (Chrome DevTools Protocol)
- MCP 0.4.0 (Model Context Protocol)
- Puma 7.1 (HTTP server)
- Zeitwerk 2.7 (Autoloading)
- Optional: whisper-cli (CAPTCHA solving)
- Optional: BotBrowser (Anti-detection)

#### Browser Compatibility
- Google Chrome / Chromium
- Microsoft Edge
- Brave Browser
- BotBrowser (commercial, optional)

#### Supported Platforms
- macOS (development)
- Linux (Docker, CI)
- Windows (untested, should work)

### Known Limitations

- **No authentication**: HTTP endpoint is open, intended for trusted environments
- **No rate limiting**: Session creation and tool execution not rate-limited
- **Branch coverage**: 55% (line coverage: 79%)

### Breaking Changes

This is the initial release, but note for future versions:

- **Session-based architecture is required**: All browser operations require an explicit `session_id`
- Pre-session architecture is fully deprecated
- `start_browser` and `stop_browser` methods raise `NotImplementedError`

### Security Notes

- **Trusted environment assumption**: No authentication on HTTP endpoint
- **Docker runs as root**: Use `--security-opt seccomp=unconfined` if needed
- **Arbitrary JavaScript execution**: `execute_script` and `evaluate_js` allow arbitrary code
- **File system access**: Screenshots and downloads have filesystem access
- **No sandboxing** beyond Chrome's built-in sandbox
- See [SECURITY.md](SECURITY.md) for security policy and responsible disclosure

### Credits

- Built with [Ferrum](https://github.com/rubycdp/ferrum) - Ruby Chrome DevTools Protocol
- Implements [Model Context Protocol](https://github.com/anthropics/mcp) by Anthropic
- Whisper integration via [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
- BotBrowser by [BotBrowser.com](https://botbrowser.com) (optional)

### Contributors

- [@Eth3rnit3](https://github.com/Eth3rnit3) - Creator and maintainer

---

## Release Links

- [0.1.0] - Initial release (2024-11-22)
- [Unreleased] - Current development

[Unreleased]: https://github.com/Eth3rnit3/FerrumMCP/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Eth3rnit3/FerrumMCP/releases/tag/v0.1.0
