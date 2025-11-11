# RSpec Tests for Ferrum MCP

This directory contains comprehensive test coverage for all Ferrum MCP tools.

## Running Tests

Run all tests:
```bash
bundle exec rspec
```

Run tests with documentation format:
```bash
bundle exec rspec --format documentation
```

Run specific test file:
```bash
bundle exec rspec spec/ferrum_mcp/tools/navigation_tools_spec.rb
```

## Test Coverage

### Navigation Tools (`navigation_tools_spec.rb`)
- NavigateTool: URL navigation and error handling
- GoBackTool: Browser history navigation backwards
- GoForwardTool: Browser history navigation forwards
- RefreshTool: Page refresh functionality

### Interaction Tools (`interaction_tools_spec.rb`)
- ClickTool: Element clicking with timeout support
- FillFormTool: Form field filling with multiple fields
- PressKeyTool: Keyboard key press simulation
- HoverTool: Mouse hover events via JavaScript

### Extraction Tools (`extraction_tools_spec.rb`)
- GetTextTool: Single and multiple element text extraction
- GetHTMLTool: Element and full page HTML retrieval
- ScreenshotTool: PNG/JPEG screenshots, full page, and element-specific captures
- GetTitleTool: Page title extraction
- GetURLTool: Current URL retrieval

### Waiting Tools (`waiting_tools_spec.rb`)
- WaitForElementTool: Wait for visible/hidden/existing elements with timeout
- WaitTool: Simple time-based waiting

### Advanced Tools (`advanced_tools_spec.rb`)
- ExecuteScriptTool: JavaScript execution
- EvaluateJSTool: JavaScript evaluation with result return
- GetCookiesTool: Cookie retrieval with domain filtering
- SetCookieTool: Cookie creation with security flags
- ClearCookiesTool: Cookie deletion (all or by domain)
- GetAttributeTool: Element attribute extraction

## Test Server

Tests use a WEBrick test server running on `http://localhost:9999` with the following endpoints:
- `/test` - Main test page with forms and interactive elements
- `/test/page2` - Secondary page for navigation testing

## Configuration

Tests use headless browser mode with error-level logging for cleaner output.
See `spec_helper.rb` for configuration details.
