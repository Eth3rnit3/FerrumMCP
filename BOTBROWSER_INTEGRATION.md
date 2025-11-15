# BotBrowser Integration Implementation Guide

## Overview

This document outlines the comprehensive strategy for integrating BotBrowser anti-detection capabilities into FerrumMCP while maintaining zero breaking changes for users who don't use BotBrowser.

## Architecture Principles

### 1. Optional Dependency Design
- BotBrowser is a runtime choice, not a hard requirement
- Standard Chrome remains the default fallback
- All tools work identically regardless of browser mode
- No additional gems or dependencies required

### 2. Configuration Strategy
- Environment variable-based configuration
- Auto-detection of BotBrowser availability
- Explicit opt-in via `BOTBROWSER_PATH` or implicit via `BOTBROWSER_PROFILE`
- Graceful degradation with clear logging

### 3. Error Handling Philosophy
- Validate BotBrowser availability at browser start, not server start
- Fall back to standard Chrome with warnings if BotBrowser fails
- Provide actionable error messages
- Never fail server startup due to BotBrowser issues

## Implementation Plan

### Phase 1: Enhanced Configuration Class

**File: `lib/ferrum_mcp/configuration.rb`**

Add these improvements:

1. **Separate browser path detection**:
   - Distinguish between explicit `BOTBROWSER_PATH` and generic `BROWSER_PATH`
   - Add method to detect if path points to BotBrowser executable

2. **Profile validation**:
   - Check if `BOTBROWSER_PROFILE` path exists
   - Support both absolute and relative profile paths
   - Validate profile structure (basic check for required files)

3. **Enhanced detection logic**:
   ```ruby
   def using_botbrowser?
     # Explicit BotBrowser configuration
     return true if botbrowser_path_configured?

     # Implicit via profile (only if browser path looks like BotBrowser)
     return true if botbrowser_profile_configured? && browser_path_is_botbrowser?

     false
   end

   def botbrowser_path_configured?
     !ENV['BOTBROWSER_PATH'].to_s.empty?
   end

   def botbrowser_profile_configured?
     !botbrowser_profile.to_s.empty?
   end

   def browser_path_is_botbrowser?
     return false if browser_path.nil?

     # Check if path contains "botbrowser" or points to known BotBrowser locations
     browser_path.downcase.include?('botbrowser')
   end

   def validate_botbrowser_setup
     return { valid: true, warnings: [] } unless using_botbrowser?

     warnings = []

     # Validate profile path
     if botbrowser_profile && !File.exist?(botbrowser_profile)
       warnings << "BotBrowser profile path does not exist: #{botbrowser_profile}"
     end

     # Validate browser executable
     if browser_path && !File.exist?(browser_path)
       warnings << "BotBrowser executable not found: #{browser_path}"
     end

     { valid: warnings.empty?, warnings: warnings }
   end
   ```

### Phase 2: Enhanced BrowserManager

**File: `lib/ferrum_mcp/browser_manager.rb`**

Improvements:

1. **Robust browser startup with fallback**:
   ```ruby
   def start
     raise BrowserError, 'Browser path is invalid' unless config.valid?

     # Try BotBrowser first if configured
     if config.using_botbrowser?
       return start_botbrowser
     end

     # Fall back to standard Chrome
     start_standard_chrome
   end

   private

   def start_botbrowser
     logger.info 'Starting BotBrowser (anti-detection mode)...'

     # Validate BotBrowser setup
     validation = config.validate_botbrowser_setup
     unless validation[:valid]
       logger.warn 'BotBrowser validation failed, falling back to standard Chrome'
       validation[:warnings].each { |warning| logger.warn "  - #{warning}" }
       return start_standard_chrome
     end

     begin
       @browser = create_browser(browser_options_botbrowser)
       logger.info 'BotBrowser started successfully'
       logger.info "Profile: #{config.botbrowser_profile}" if config.botbrowser_profile
       @browser
     rescue StandardError => e
       logger.error "Failed to start BotBrowser: #{e.message}"
       logger.warn 'Falling back to standard Chrome...'
       start_standard_chrome
     end
   end

   def start_standard_chrome
     logger.info 'Starting browser with standard Chrome/Chromium...'

     begin
       @browser = create_browser(browser_options_standard)
       logger.info 'Standard Chrome started successfully'
       @browser
     rescue StandardError => e
       logger.error "Failed to start browser: #{e.message}"
       raise BrowserError, "Failed to start browser: #{e.message}"
     end
   end

   def create_browser(browser_opts)
     options_hash = {
       browser_options: browser_opts,
       headless: config.headless,
       timeout: config.timeout,
       process_timeout: ENV['CI'] ? 120 : config.timeout,
       pending_connection_errors: false
     }

     # Only set browser_path if explicitly configured
     options_hash[:browser_path] = config.browser_path if config.browser_path

     Ferrum::Browser.new(**options_hash)
   end
   ```

2. **Separate browser options for each mode**:
   ```ruby
   def browser_options_botbrowser
     options = {
       '--no-sandbox' => nil,
       '--disable-dev-shm-usage' => nil,
       '--disable-gpu' => nil
     }

     # CI-specific options
     options['--disable-setuid-sandbox'] = nil if ENV['CI']

     # BotBrowser-specific options
     if config.botbrowser_profile && File.exist?(config.botbrowser_profile)
       options['--bot-profile'] = config.botbrowser_profile
       logger.info "Using BotBrowser profile: #{config.botbrowser_profile}"
     end

     # BotBrowser works better with these disabled
     # (it handles automation detection internally)
     # Do NOT add --disable-blink-features=AutomationControlled
     # as BotBrowser manages this more sophisticatedly

     options
   end

   def browser_options_standard
     options = {
       '--no-sandbox' => nil,
       '--disable-dev-shm-usage' => nil,
       '--disable-blink-features' => 'AutomationControlled',
       '--disable-gpu' => nil
     }

     # CI-specific options
     options['--disable-setuid-sandbox'] = nil if ENV['CI']

     options
   end
   ```

### Phase 3: Startup Validation

**File: `server.rb`**

Add BotBrowser-specific validation messaging:

```ruby
# After line 68: Validate configuration
unless config.valid?
  puts 'ERROR: Invalid browser configuration'
  puts 'The specified BROWSER_PATH does not exist'
  puts ''
  puts 'Options:'
  puts '  1. Remove BROWSER_PATH to use system Chrome/Chromium'
  puts '  2. Set BROWSER_PATH to a valid browser executable'
  puts '  3. Set BOTBROWSER_PATH to use BotBrowser anti-detection'
  puts ''
  puts 'Example: export BROWSER_PATH=/path/to/chrome'
  puts 'Example: export BOTBROWSER_PATH=/path/to/botbrowser'
  exit 1
end

# Validate BotBrowser setup if configured
if config.using_botbrowser?
  validation = config.validate_botbrowser_setup

  unless validation[:valid]
    puts 'WARNING: BotBrowser configuration has issues:'
    validation[:warnings].each { |warning| puts "  - #{warning}" }
    puts ''
    puts 'Server will start but may fall back to standard Chrome'
    puts ''
  end
end
```

### Phase 4: Environment Variables Documentation

Update the help text in `server.rb`:

```ruby
opts.separator 'Environment variables:'
opts.separator '  BROWSER_PATH        - Path to Chrome/Chromium executable (optional)'
opts.separator '  BOTBROWSER_PATH     - Path to BotBrowser executable (optional, overrides BROWSER_PATH)'
opts.separator '  BOTBROWSER_PROFILE  - Path to BotBrowser profile for anti-detection (optional)'
opts.separator '  BROWSER_HEADLESS    - Run browser in headless mode (true/false, default: false)'
opts.separator '  BROWSER_TIMEOUT     - Browser timeout in seconds (default: 60)'
opts.separator '  MCP_SERVER_HOST     - HTTP server host (default: 0.0.0.0)'
opts.separator '  MCP_SERVER_PORT     - HTTP server port (default: 3000)'
opts.separator '  LOG_LEVEL           - Log level (debug/info/warn/error, default: debug)'
opts.separator ''
opts.separator 'BotBrowser Integration:'
opts.separator '  To use BotBrowser anti-detection features:'
opts.separator '    1. Set BOTBROWSER_PATH to your BotBrowser executable'
opts.separator '    2. (Optional) Set BOTBROWSER_PROFILE to a profile path'
opts.separator '  If BotBrowser fails to start, server will fall back to standard Chrome'
```

### Phase 5: Testing Strategy

**File: `spec/ferrum_mcp/browser_manager_spec.rb`** (new file)

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::BrowserManager do
  let(:config) { FerrumMCP::Configuration.new }
  let(:manager) { described_class.new(config) }

  describe '#start' do
    context 'with standard Chrome' do
      before do
        allow(config).to receive(:using_botbrowser?).and_return(false)
      end

      it 'starts standard Chrome successfully' do
        browser = manager.start
        expect(browser).to be_a(Ferrum::Browser)
        expect(manager.active?).to be true
        manager.stop
      end

      it 'logs standard Chrome mode' do
        expect(config.logger).to receive(:info).with('Starting browser with standard Chrome/Chromium...')
        expect(config.logger).to receive(:info).with('Standard Chrome started successfully')
        manager.start
        manager.stop
      end
    end

    context 'with BotBrowser configured' do
      before do
        allow(config).to receive(:using_botbrowser?).and_return(true)
        allow(config).to receive(:botbrowser_profile).and_return('/tmp/test-profile')
        allow(config).to receive(:validate_botbrowser_setup).and_return({ valid: true, warnings: [] })
      end

      it 'attempts to start BotBrowser' do
        expect(config.logger).to receive(:info).with('Starting BotBrowser (anti-detection mode)...')

        # Will fall back to standard Chrome in test environment (BotBrowser not installed)
        expect(config.logger).to receive(:warn).with('Falling back to standard Chrome...')

        browser = manager.start
        expect(browser).to be_a(Ferrum::Browser)
        manager.stop
      end
    end

    context 'with invalid BotBrowser configuration' do
      before do
        allow(config).to receive(:using_botbrowser?).and_return(true)
        allow(config).to receive(:validate_botbrowser_setup).and_return({
          valid: false,
          warnings: ['Profile path does not exist']
        })
      end

      it 'falls back to standard Chrome with warnings' do
        expect(config.logger).to receive(:warn).with('BotBrowser validation failed, falling back to standard Chrome')
        expect(config.logger).to receive(:warn).with('  - Profile path does not exist')

        browser = manager.start
        expect(browser).to be_a(Ferrum::Browser)
        manager.stop
      end
    end
  end
end
```

**Update: `spec/ferrum_mcp/configuration_spec.rb`**

Add tests for new methods:

```ruby
describe '#validate_botbrowser_setup' do
  context 'when not using BotBrowser' do
    it 'returns valid with no warnings' do
      config = described_class.new
      result = config.validate_botbrowser_setup
      expect(result[:valid]).to be true
      expect(result[:warnings]).to be_empty
    end
  end

  context 'when BotBrowser profile does not exist' do
    it 'returns invalid with warning' do
      config = described_class.new
      config.botbrowser_profile = '/non/existent/profile'
      allow(config).to receive(:using_botbrowser?).and_return(true)

      result = config.validate_botbrowser_setup
      expect(result[:valid]).to be false
      expect(result[:warnings]).to include(/profile path does not exist/i)
    end
  end
end
```

## Configuration Examples

### Example 1: Standard Chrome (Default)

```bash
# No BotBrowser configuration - uses system Chrome
ruby server.rb
```

### Example 2: Explicit BotBrowser with Profile

```bash
# .env file
BOTBROWSER_PATH=/Applications/BotBrowser.app/Contents/MacOS/BotBrowser
BOTBROWSER_PROFILE=/Users/username/.botbrowser/profiles/default
BROWSER_HEADLESS=false

ruby server.rb
```

### Example 3: BotBrowser with Docker

```dockerfile
# Dockerfile with BotBrowser
FROM ruby:3.2

# Install BotBrowser
RUN wget https://botbrowser.com/download/linux && \
    chmod +x botbrowser && \
    mv botbrowser /usr/local/bin/

# Copy application
COPY . /app
WORKDIR /app

ENV BOTBROWSER_PATH=/usr/local/bin/botbrowser
ENV BOTBROWSER_PROFILE=/app/profiles/stealth

CMD ["ruby", "server.rb"]
```

### Example 4: Claude Desktop Integration with BotBrowser

```json
{
  "mcpServers": {
    "ferrum-mcp-stealth": {
      "command": "/Users/username/.rbenv/versions/3.3.5/bin/ruby",
      "args": [
        "/Users/username/code/ferrum-mcp/server.rb",
        "--transport",
        "stdio"
      ],
      "env": {
        "BOTBROWSER_PATH": "/Applications/BotBrowser.app/Contents/MacOS/BotBrowser",
        "BOTBROWSER_PROFILE": "/Users/username/.botbrowser/profiles/default",
        "BROWSER_HEADLESS": "false",
        "LOG_LEVEL": "info"
      }
    }
  }
}
```

## Migration Guide

### For Existing Users

No action required! Your existing configuration will continue to work. FerrumMCP will use standard Chrome as before.

### For Users Wanting BotBrowser

1. Download and install BotBrowser from [botbrowser.com](https://botbrowser.com)
2. Set environment variables:
   ```bash
   export BOTBROWSER_PATH=/path/to/botbrowser
   export BOTBROWSER_PROFILE=/path/to/profile  # Optional
   ```
3. Restart FerrumMCP server
4. Check logs to confirm BotBrowser is active

## Troubleshooting

### Issue: BotBrowser not starting

**Symptoms**: Log shows "Falling back to standard Chrome"

**Solutions**:
1. Verify `BOTBROWSER_PATH` points to correct executable
2. Ensure BotBrowser is properly installed and licensed
3. Check profile path exists if `BOTBROWSER_PROFILE` is set
4. Review log file for detailed error messages

### Issue: Profile not loading

**Symptoms**: BotBrowser starts but profile settings not applied

**Solutions**:
1. Verify profile path is absolute (not relative)
2. Ensure profile directory has correct permissions
3. Test profile works with BotBrowser directly
4. Check BotBrowser version compatibility

### Issue: CDP connection errors

**Symptoms**: "Failed to connect to browser" errors

**Solutions**:
1. Ensure no other BotBrowser instances are running
2. Try increasing `BROWSER_TIMEOUT` value
3. Check firewall/security software isn't blocking connections
4. Verify port 9222 (default CDP port) is available

## Performance Considerations

### BotBrowser Mode
- Slightly higher memory usage (100-200MB more)
- Minimal CPU overhead
- Same automation speed as standard Chrome
- Better success rate on anti-bot protected sites

### When to Use BotBrowser
- Scraping protected websites
- Automation that needs to appear human-like
- Sites with advanced bot detection
- Production/commercial use cases

### When Standard Chrome is Fine
- Development/testing
- Internal tools
- Sites without bot protection
- Resource-constrained environments

## Security Notes

1. **Profile Security**: BotBrowser profiles may contain sensitive data (cookies, credentials). Store profiles securely and never commit to version control.

2. **License Compliance**: BotBrowser is a commercial product. Ensure you have proper licensing for your use case.

3. **CDP Security**: Chrome DevTools Protocol exposes full browser control. Only run FerrumMCP in trusted environments.

## Future Enhancements

Potential improvements for future versions:

1. **Profile Management**: Built-in profile creation and management
2. **Fingerprint Rotation**: Automatic fingerprint rotation per session
3. **Proxy Integration**: Seamless proxy configuration for BotBrowser
4. **Health Checks**: Automated BotBrowser health monitoring
5. **Performance Metrics**: Track success rates between modes

## References

- [BotBrowser Documentation](https://botbrowser.com/docs)
- [Ferrum Documentation](https://github.com/rubycdp/ferrum)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Model Context Protocol](https://modelcontextprotocol.io)
