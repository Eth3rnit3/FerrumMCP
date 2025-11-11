# Usage Guide

## Starting the Server

```bash
bundle exec ruby server.rb
```

The server will start on `http://localhost:3000` by default.

## Testing the Server

### Health Check

```bash
curl http://localhost:3000/health
```

Response:
```json
{"status":"ok"}
```

### Server Info

```bash
curl http://localhost:3000/
```

Response:
```json
{
  "name": "Ferrum MCP Server",
  "version": "0.1.0",
  "endpoints": {
    "mcp": "/mcp",
    "health": "/health"
  }
}
```

## Using MCP Tools

All MCP requests are sent to `/mcp` endpoint via POST with JSON-RPC 2.0 format.

### Example: Navigate to a URL

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {
        "url": "https://example.com"
      }
    },
    "id": 1
  }'
```

Response:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "data": {
      "url": "https://example.com",
      "title": "Example Domain"
    }
  },
  "id": 1
}
```

### Example: Click an Element

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "click",
      "arguments": {
        "selector": "button.submit"
      }
    },
    "id": 2
  }'
```

### Example: Fill a Form

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "fill_form",
      "arguments": {
        "fields": [
          {"selector": "#email", "value": "user@example.com"},
          {"selector": "#password", "value": "secret123"}
        ]
      }
    },
    "id": 3
  }'
```

### Example: Take a Screenshot

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "screenshot",
      "arguments": {
        "full_page": true,
        "format": "png"
      }
    },
    "id": 4
  }'
```

Response includes base64-encoded image:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "data": {
      "screenshot": "iVBORw0KGgoAAAANS...",
      "format": "png",
      "encoding": "base64"
    }
  },
  "id": 4
}
```

## List Available Tools

```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {},
    "id": 5
  }'
```

This returns all available tools with their descriptions and input schemas.

## Integration with Claude Desktop

Add to your Claude Desktop configuration file:

**macOS/Linux**: `~/.config/claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "ferrum-browser": {
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

Restart Claude Desktop, and you'll see the Ferrum MCP tools available.

## Integration with Other MCP Clients

Any MCP client can connect to the server using the HTTP transport:

```python
# Python example
import requests

def call_mcp_tool(tool_name, arguments):
    response = requests.post(
        "http://localhost:3000/mcp",
        json={
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            },
            "id": 1
        }
    )
    return response.json()

# Use it
result = call_mcp_tool("navigate", {"url": "https://example.com"})
print(result)
```

## Available Tools

See [API.md](API.md) for complete documentation of all available tools.

## Error Handling

All tools return a response with `success` field:

```json
{
  "success": true,
  "data": { ... }
}
```

Or in case of error:

```json
{
  "success": false,
  "error": "Error message here"
}
```

## Browser Lifecycle

The browser starts automatically on the first tool call and stays running. You can restart it by stopping the server and starting it again.

The browser will be in:
- **Headless mode**: If `BROWSER_HEADLESS=true`
- **Headed mode**: If `BROWSER_HEADLESS=false` (you'll see the browser window)

## Tips

1. **Use wait tools**: After navigation or clicks, use `wait_for_element` to ensure elements are ready
2. **Take screenshots**: Useful for debugging - see what the page looks like
3. **Check the logs**: The server logs all actions and errors
4. **Use CSS selectors**: All element selection uses standard CSS selectors
5. **Handle timeouts**: Adjust `BROWSER_TIMEOUT` if pages load slowly
