# Troubleshooting Guide

This guide helps you diagnose and fix common issues with FerrumMCP.

## Table of Contents

- [Server Won't Start](#server-wont-start)
- [Browser Issues](#browser-issues)
- [Session Management](#session-management)
- [Tool Errors](#tool-errors)
- [Claude Desktop Integration](#claude-desktop-integration)
- [Docker Issues](#docker-issues)
- [BotBrowser Integration](#botbrowser-integration)
- [Performance Issues](#performance-issues)
- [Logging and Debugging](#logging-and-debugging)

---

## Server Won't Start

### Error: `cannot load such file -- ferrum`

**Cause**: Dependencies not installed

**Solution**:
```bash
bundle install
```

### Error: `Address already in use - bind(2) for "0.0.0.0" port 3000`

**Cause**: Port 3000 is already in use

**Solution**:
```bash
# Find process using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use a different port
MCP_SERVER_PORT=3001 ruby server.rb
```

### Error: `Zeitwerk::NameError: expected file ... to define constant ...`

**Cause**: File naming doesn't match class name

**Solution**:
```bash
# Check Zeitwerk eager loading
bundle exec rake zeitwerk:check
```

Fix any naming mismatches reported.

### Error: `Browser path not found: /path/to/chrome`

**Cause**: Chrome/Chromium not installed or wrong path

**Solution**:

**macOS**:
```bash
# Chrome
BROWSER_CHROME=chrome:/Applications/Google Chrome.app/Contents/MacOS/Google Chrome:Chrome:Default

# Or use system default
BROWSER_CHROME=chrome::Chrome:Default
```

**Linux**:
```bash
# Find Chrome
which google-chrome
which chromium-browser

# Set path
BROWSER_CHROME=chrome:/usr/bin/google-chrome:Chrome:Default
```

---

## Browser Issues

### Error: `Ferrum::DeadBrowserError: Browser is dead`

**Cause**: Browser crashed or was killed

**Solution**:
1. Close the affected session: `close_session(session_id: "...")`
2. Create a new session
3. Check logs for crash reason: `logs/ferrum_mcp.log`

**Common causes**:
- Out of memory
- Browser timeout exceeded
- Incompatible Chrome version

### Error: `Ferrum::TimeoutError: Timed out waiting for response`

**Cause**: Browser operation took too long

**Solution**:
```bash
# Increase timeout
BROWSER_TIMEOUT=120 ruby server.rb
```

Or when creating session:
```ruby
create_session(timeout: 120)
```

### Error: `Chrome failed to start: exited abnormally`

**Cause**: Chrome can't run (usually in Docker/CI)

**Solution**:

**Docker**:
```bash
# Run with required security options
docker run --shm-size=2g \
  --security-opt seccomp=unconfined \
  -p 3000:3000 \
  eth3rnit3/ferrum-mcp
```

**Headless mode**:
```bash
BROWSER_HEADLESS=true ruby server.rb
```

### Browser window appears but doesn't load pages

**Cause**: Network connectivity or DNS issues

**Solution**:
```ruby
# Test with simple page
navigate(url: "https://example.com", session_id: "...")

# Check logs
tail -f logs/ferrum_mcp.log
```

**Check**:
- Internet connectivity
- Proxy settings
- Firewall rules

---

## Session Management

### Error: `SessionError: Session not found`

**Cause**: Session doesn't exist or was closed

**Solution**:
```ruby
# List active sessions
list_sessions()

# Create new session
session_id = create_session()
```

### Sessions not auto-closing

**Cause**: Sessions are being actively used (no idle time)

**Behavior**: Sessions only close after 30 minutes of **inactivity**

**Solution**: Close sessions manually when done:
```ruby
close_session(session_id: "...")
```

### Too many sessions consuming resources

**Current behavior**: No hard limit on concurrent sessions

**Solution**:
```ruby
# List all sessions
sessions = list_sessions()

# Close inactive sessions
sessions.each do |session|
  close_session(session_id: session['session_id'])
end
```

**Note**: Session limits (`MAX_CONCURRENT_SESSIONS`) planned for v1.1

---

## Tool Errors

### Error: `ToolError: Element not found`

**Cause**: Element doesn't exist or CSS/XPath selector is wrong

**Solution**:
```ruby
# Debug: Get page HTML
html = get_html(session_id: "...")

# Try different selectors
# CSS: .class-name, #id, button[type="submit"]
# XPath: //button[@type="submit"]

# Wait for element to appear (if page is loading)
# Note: wait_for_element is currently disabled
# Use navigate with wait for idle instead
navigate(url: "...", wait_until: "networkidle", session_id: "...")
```

### Error: `ToolError: Stale element reference`

**Cause**: Element changed after being found (page modified)

**Solution**: Tools automatically retry 3 times. If still failing:
```ruby
# Refresh page and try again
refresh(session_id: "...")
click(selector: "...", session_id: "...")
```

### Screenshot returns blank/black image

**Cause**: Page not fully loaded or rendering issue

**Solution**:
```ruby
# Wait for page to load
navigate(url: "...", session_id: "...")
# Add delay (wait tool currently disabled)
# Take screenshot
screenshot(session_id: "...")
```

### Fill form doesn't work

**Cause**: Form field not found or not interactable

**Solution**:
```ruby
# 1. Verify field exists
get_html(session_id: "...")

# 2. Click field first to focus
click(selector: "input[name='username']", session_id: "...")

# 3. Fill form
fill_form(
  fields: { "input[name='username']": "myusername" },
  session_id: "..."
)
```

### JavaScript execution fails

**Cause**: Syntax error or browser context issue

**Solution**:
```ruby
# For return value, use evaluate_js
result = evaluate_js(
  script: "document.title",
  session_id: "..."
)

# For side effects, use execute_script
execute_script(
  script: "document.querySelector('#btn').click()",
  session_id: "..."
)

# Debug errors
execute_script(
  script: "console.log('Debug output')",
  session_id: "..."
)
# Check browser console logs
```

---

## Claude Desktop Integration

### Claude Desktop doesn't show FerrumMCP

**Cause**: Configuration error or server not starting

**Solution**:

1. **Check config file location**:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
   - Linux: `~/.config/Claude/claude_desktop_config.json`

2. **Verify JSON syntax**:
   ```bash
   # macOS
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq .
   ```

3. **Check paths are absolute**:
   ```json
   {
     "mcpServers": {
       "ferrum-mcp": {
         "command": "/Users/username/.rbenv/versions/3.3.5/bin/ruby",
         "args": [
           "/Users/username/code/ferrum-mcp/server.rb",
           "--transport",
           "stdio"
         ]
       }
     }
   }
   ```

4. **Restart Claude Desktop** completely (quit and reopen)

5. **Check logs**:
   ```bash
   tail -f ~/code/ferrum-mcp/logs/ferrum_mcp.log
   ```

### Error: `command not found: ruby`

**Cause**: Ruby path is wrong or not absolute

**Solution**:
```bash
# Find Ruby path
which ruby
# Example: /Users/username/.rbenv/versions/3.3.5/bin/ruby

# Use absolute path in config
```

### Claude says "Tool not available"

**Cause**: Server not running or communication issue

**Solution**:
1. Test server manually:
   ```bash
   ruby server.rb --transport stdio
   # Type: {"method": "list_tools"}
   # Press Enter
   ```

2. Check for error output
3. Verify Ruby version: `ruby --version` (need 3.2+)

---

## Docker Issues

### Error: `docker: no matching manifest for linux/arm64`

**Cause**: Image not built for ARM architecture (M1/M2 Macs)

**Current status**: Multi-platform builds enabled (amd64, arm64)

**Solution**:
```bash
# Pull latest image
docker pull eth3rnit3/ferrum-mcp:latest

# Or build locally
docker build --platform linux/arm64 -t ferrum-mcp .
```

### Container starts but server not accessible

**Cause**: Port mapping or firewall issue

**Solution**:
```bash
# Check container is running
docker ps

# Check port mapping
docker port <container_id>

# Correct mapping
docker run -p 3000:3000 eth3rnit3/ferrum-mcp
```

### Chrome crashes in Docker

**Cause**: Insufficient shared memory

**Solution**:
```bash
docker run --shm-size=2g \
  -p 3000:3000 \
  eth3rnit3/ferrum-mcp
```

### Permission denied errors in Docker

**Cause**: Container running as root

**Solution** (workaround until v1.1):
```bash
docker run --user 1000:1000 \
  -p 3000:3000 \
  eth3rnit3/ferrum-mcp
```

---

## BotBrowser Integration

See [BOTBROWSER_INTEGRATION.md](BOTBROWSER_INTEGRATION.md) for detailed troubleshooting.

### Error: `BotBrowser path not found`

**Solution**:
```bash
# Verify BotBrowser installed
ls /opt/botbrowser/chrome

# Set path
BROWSER_BOTBROWSER=botbrowser:/opt/botbrowser/chrome:BotBrowser:Anti-detection
```

### Error: `Failed to load profile`

**Cause**: Invalid or encrypted profile

**Solution**:
```bash
# Verify profile exists
ls /path/to/profile.enc

# Set profile
BOT_PROFILE_US=/path/to/profile.enc:US Chrome:US fingerprint

# Check profile is encrypted (.enc extension)
```

### BotBrowser session slower than regular Chrome

**Expected behavior**: Anti-detection adds overhead

**Mitigation**:
- Use regular Chrome for non-protected sites
- Increase timeout for BotBrowser sessions
- Use separate session for BotBrowser

---

## Performance Issues

### High memory usage

**Cause**: Multiple sessions or memory leak

**Solution**:
```bash
# Monitor sessions
list_sessions()

# Close unused sessions
close_session(session_id: "...")

# Enable headless mode
BROWSER_HEADLESS=true ruby server.rb

# Limit concurrent sessions (manual until v1.1)
```

### Slow tool execution

**Cause**: Network latency, page load time, or timeouts

**Solution**:
```ruby
# Increase timeout
create_session(timeout: 120)

# Use headless mode (faster)
create_session(headless: true)

# Navigate with faster wait condition
navigate(url: "...", wait_until: "domcontentloaded", session_id: "...")
```

### CPU usage spikes

**Cause**: Multiple browsers or heavy page rendering

**Solution**:
- Limit concurrent sessions
- Use headless mode
- Close sessions when done
- Monitor: `htop` or Activity Monitor

---

## Logging and Debugging

### Enable debug logging

```bash
LOG_LEVEL=debug ruby server.rb
```

### Check logs

```bash
# View logs
tail -f logs/ferrum_mcp.log

# Search for errors
grep ERROR logs/ferrum_mcp.log

# Search for specific session
grep "session-123" logs/ferrum_mcp.log
```

### Log levels

- `DEBUG`: Detailed execution traces
- `INFO`: Session lifecycle, tool execution (default)
- `WARN`: Degraded functionality
- `ERROR`: Failures requiring attention

### Common log errors

**`ERROR -- : Browser startup failed`**
→ Check browser path and installation

**`ERROR -- : Session not found`**
→ Session expired or invalid session_id

**`WARN -- : Session idle timeout reached`**
→ Normal, session auto-closed after 30 minutes

**`ERROR -- : Stale element reference`**
→ Tool automatically retries, usually recovers

### Enable RSpec verbose output

```bash
bundle exec rspec --format documentation
```

### Test specific scenario

```bash
# Create test script
cat > test_scenario.rb << 'EOF'
require_relative 'lib/ferrum_mcp'

config = FerrumMCP::Configuration.new
server = FerrumMCP::Server.new(config)

# Your test code here
session_id = server.execute_tool('create_session', { headless: false })
puts "Session created: #{session_id}"
EOF

ruby test_scenario.rb
```

---

## Getting Help

If you're still stuck:

1. **Check documentation**:
   - [Getting Started](GETTING_STARTED.md)
   - [API Reference](API_REFERENCE.md)
   - [Configuration](CONFIGURATION.md)

2. **Search existing issues**:
   - [GitHub Issues](https://github.com/Eth3rnit3/FerrumMCP/issues)

3. **Enable debug logging**:
   ```bash
   LOG_LEVEL=debug ruby server.rb
   ```

4. **Create a minimal reproduction**:
   - Simplest possible steps to reproduce
   - Include error messages
   - Share logs (redact sensitive info)

5. **Open an issue**:
   - Use bug report template
   - Include environment details
   - Attach logs and screenshots

6. **Contact**:
   - Email: [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com)

---

## Quick Diagnostic Checklist

Before opening an issue, verify:

- [ ] Ruby version ≥ 3.2: `ruby --version`
- [ ] Dependencies installed: `bundle install`
- [ ] Chrome installed: `which google-chrome` or `which chromium-browser`
- [ ] Port available: `lsof -i :3000`
- [ ] Logs checked: `tail -f logs/ferrum_mcp.log`
- [ ] Configuration valid: Check `.env` file
- [ ] RuboCop passes: `bundle exec rubocop`
- [ ] Tests pass: `bundle exec rspec`

---

**Last Updated**: 2024-11-22
