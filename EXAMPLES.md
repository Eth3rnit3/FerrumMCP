# Examples

Real-world examples of using Ferrum MCP Server.

## Example 1: Google Search

```bash
# Navigate to Google
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://www.google.com"}
    },
    "id": 1
  }'

# Fill search field
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "fill_form",
      "arguments": {
        "fields": [
          {"selector": "textarea[name=q]", "value": "Model Context Protocol"}
        ]
      }
    },
    "id": 2
  }'

# Press Enter to search
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "press_key",
      "arguments": {"key": "Enter"}
    },
    "id": 3
  }'

# Wait for results
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "wait_for_element",
      "arguments": {"selector": "#search"}
    },
    "id": 4
  }'

# Get search results
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_text",
      "arguments": {
        "selector": "h3",
        "multiple": true
      }
    },
    "id": 5
  }'
```

## Example 2: Login to Website

```bash
# Navigate to login page
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://example.com/login"}
    },
    "id": 1
  }'

# Fill login form
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "fill_form",
      "arguments": {
        "fields": [
          {"selector": "#username", "value": "myuser"},
          {"selector": "#password", "value": "mypass"}
        ]
      }
    },
    "id": 2
  }'

# Click submit button
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "click",
      "arguments": {"selector": "button[type=submit]"}
    },
    "id": 3
  }'

# Wait for dashboard
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "wait_for_element",
      "arguments": {"selector": ".dashboard"}
    },
    "id": 4
  }'

# Verify login
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_url",
      "arguments": {}
    },
    "id": 5
  }'
```

## Example 3: Scrape Article Content

```bash
# Navigate to article
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://example.com/article"}
    },
    "id": 1
  }'

# Get article title
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_text",
      "arguments": {"selector": "h1.article-title"}
    },
    "id": 2
  }'

# Get article content
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_html",
      "arguments": {"selector": "article.content"}
    },
    "id": 3
  }'

# Get all paragraph texts
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_text",
      "arguments": {
        "selector": "article p",
        "multiple": true
      }
    },
    "id": 4
  }'
```

## Example 4: Take Full Page Screenshot

```bash
# Navigate to page
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://example.com"}
    },
    "id": 1
  }'

# Wait for page to load
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "wait",
      "arguments": {"seconds": 2}
    },
    "id": 2
  }'

# Take full page screenshot
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
    "id": 3
  }' | jq -r '.result.data.screenshot' | base64 -d > screenshot.png
```

## Example 5: Handle Dynamic Content

```bash
# Navigate to dynamic page
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://example.com/dynamic"}
    },
    "id": 1
  }'

# Click load more button
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "click",
      "arguments": {"selector": "button.load-more"}
    },
    "id": 2
  }'

# Wait for new content
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "wait_for_element",
      "arguments": {
        "selector": ".item:nth-child(20)",
        "timeout": 10
      }
    },
    "id": 3
  }'

# Get all items
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_text",
      "arguments": {
        "selector": ".item",
        "multiple": true
      }
    },
    "id": 4
  }'
```

## Example 6: Working with Cookies

```bash
# Navigate to site
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://example.com"}
    },
    "id": 1
  }'

# Set a custom cookie
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "set_cookie",
      "arguments": {
        "name": "user_pref",
        "value": "dark_mode",
        "domain": ".example.com",
        "path": "/"
      }
    },
    "id": 2
  }'

# Refresh to apply cookie
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "refresh",
      "arguments": {}
    },
    "id": 3
  }'

# Get all cookies
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_cookies",
      "arguments": {}
    },
    "id": 4
  }'
```

## Example 7: JavaScript Execution

```bash
# Navigate to page
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "navigate",
      "arguments": {"url": "https://example.com"}
    },
    "id": 1
  }'

# Evaluate JavaScript
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "evaluate_js",
      "arguments": {
        "expression": "document.querySelectorAll(\"a\").length"
      }
    },
    "id": 2
  }'

# Execute JavaScript to modify page
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "execute_script",
      "arguments": {
        "script": "document.querySelector(\"h1\").style.color = \"red\";"
      }
    },
    "id": 3
  }'

# Take screenshot to verify
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "screenshot",
      "arguments": {"format": "png"}
    },
    "id": 4
  }'
```

## Python Helper Script

```python
#!/usr/bin/env python3
import requests
import json

class FerrumMCP:
    def __init__(self, base_url="http://localhost:3000"):
        self.base_url = base_url
        self.request_id = 0

    def call_tool(self, tool_name, arguments=None):
        self.request_id += 1
        response = requests.post(
            f"{self.base_url}/mcp",
            json={
                "jsonrpc": "2.0",
                "method": "tools/call",
                "params": {
                    "name": tool_name,
                    "arguments": arguments or {}
                },
                "id": self.request_id
            }
        )
        return response.json()

# Usage
browser = FerrumMCP()

# Navigate
result = browser.call_tool("navigate", {"url": "https://example.com"})
print(f"Navigated to: {result['result']['data']['title']}")

# Get text
result = browser.call_tool("get_text", {"selector": "h1"})
print(f"H1 text: {result['result']['data']['text']}")

# Take screenshot
result = browser.call_tool("screenshot", {"format": "png"})
if result['result']['success']:
    import base64
    screenshot_data = base64.b64decode(result['result']['data']['screenshot'])
    with open('screenshot.png', 'wb') as f:
        f.write(screenshot_data)
    print("Screenshot saved to screenshot.png")
```
