# Project Structure

## Directory Layout

```
ferrum-mcp/
├── lib/                          # Main library code
│   ├── ferrum_mcp.rb            # Main module loader
│   └── ferrum_mcp/
│       ├── version.rb           # Version constant
│       ├── configuration.rb     # Configuration management
│       ├── browser_manager.rb   # Browser lifecycle management
│       ├── server.rb            # MCP server implementation
│       ├── tools/               # Tool implementations
│       │   ├── base_tool.rb           # Base class for all tools
│       │   ├── navigation_tools.rb    # Navigate, back, forward, refresh
│       │   ├── interaction_tools.rb   # Click, fill, press, hover
│       │   ├── extraction_tools.rb    # Get text, HTML, screenshot, etc.
│       │   ├── waiting_tools.rb       # Wait for elements/navigation
│       │   └── advanced_tools.rb      # JS execution, cookies, attributes
│       └── transport/
│           └── http_server.rb   # HTTP/SSE transport layer
├── config/                       # Configuration files
│   └── profile.enc              # BotBrowser profile (not in repo)
├── bin/                          # Binaries
│   └── botbrowser/              # BotBrowser binary (not in repo)
├── server.rb                     # Server entry point
├── Gemfile                       # Ruby dependencies
├── Rakefile                      # Development tasks
├── .env                          # Environment configuration (not in repo)
├── .env.example                  # Example environment config
├── .gitignore                    # Git ignore rules
├── .rubocop.yml                  # RuboCop linter config
├── LICENSE                       # MIT License
└── docs/                         # Documentation
    ├── README.md                 # Main documentation
    ├── QUICKSTART.md             # 5-minute quick start
    ├── INSTALLATION.md           # Detailed installation
    ├── USAGE.md                  # Usage guide
    ├── API.md                    # API reference
    └── EXAMPLES.md               # Usage examples
```

## Module Organization

### Core Modules

- **FerrumMCP**: Root module
- **FerrumMCP::Configuration**: Environment and settings management
- **FerrumMCP::BrowserManager**: Ferrum browser lifecycle
- **FerrumMCP::Server**: MCP server implementation
- **FerrumMCP::Transport::HTTPServer**: HTTP transport layer

### Tool Categories

1. **Navigation Tools** (4 tools)
   - NavigateTool
   - GoBackTool
   - GoForwardTool
   - RefreshTool

2. **Interaction Tools** (4 tools)
   - ClickTool
   - FillFormTool
   - PressKeyTool
   - HoverTool

3. **Extraction Tools** (5 tools)
   - GetTextTool
   - GetHTMLTool
   - ScreenshotTool
   - GetTitleTool
   - GetURLTool

4. **Waiting Tools** (3 tools)
   - WaitForElementTool
   - WaitForNavigationTool
   - WaitTool

5. **Advanced Tools** (6 tools)
   - ExecuteScriptTool
   - EvaluateJSTool
   - GetCookiesTool
   - SetCookieTool
   - ClearCookiesTool
   - GetAttributeTool

**Total: 22 tools**

## Key Files

### Entry Points

- `server.rb` - Main server entry point
- `lib/ferrum_mcp.rb` - Library entry point

### Configuration

- `.env` - Environment variables (user-created)
- `.env.example` - Template for environment config
- `lib/ferrum_mcp/configuration.rb` - Configuration class

### Server Core

- `lib/ferrum_mcp/server.rb` - MCP server implementation
- `lib/ferrum_mcp/browser_manager.rb` - Browser management
- `lib/ferrum_mcp/transport/http_server.rb` - HTTP transport

### Tools Base

- `lib/ferrum_mcp/tools/base_tool.rb` - Base class with common functionality

## Dependencies

### Runtime Dependencies

- `mcp` (~> 0.1) - MCP SDK
- `ferrum` (~> 0.15) - Browser automation
- `puma` (~> 6.0) - HTTP server
- `rack` (~> 3.0) - HTTP middleware
- `json` (~> 2.7) - JSON handling
- `logger` (~> 1.6) - Logging

### Development Dependencies

- `rspec` (~> 3.12) - Testing
- `rubocop` (~> 1.50) - Linting
- `pry` (~> 0.14) - Debugging

## Design Principles

1. **Modularity**: Each tool is in its own class
2. **Separation of Concerns**: Transport, server, tools, and browser management are separate
3. **Single Responsibility**: Each file has one clear purpose
4. **Easy Maintenance**: Short, focused files that are easy to understand
5. **Extensibility**: Easy to add new tools by subclassing BaseTool

## File Size Guidelines

- Tool files: 50-200 lines each
- Core modules: 100-300 lines each
- Entry points: 50-100 lines each

## Adding New Tools

To add a new tool:

1. Create tool class in appropriate tools file (or new file)
2. Inherit from `FerrumMCP::Tools::BaseTool`
3. Implement class methods: `tool_name`, `description`, `input_schema`
4. Implement instance method: `execute(params)`
5. Add tool class to `TOOL_CLASSES` array in `server.rb`
6. Require the file in `lib/ferrum_mcp.rb` if it's a new file

## Testing Structure

Tests should mirror the lib structure:

```
spec/
├── ferrum_mcp/
│   ├── configuration_spec.rb
│   ├── browser_manager_spec.rb
│   ├── server_spec.rb
│   ├── tools/
│   │   ├── navigation_tools_spec.rb
│   │   ├── interaction_tools_spec.rb
│   │   └── ...
│   └── transport/
│       └── http_server_spec.rb
└── spec_helper.rb
```
