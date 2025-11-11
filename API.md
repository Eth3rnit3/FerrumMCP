# API Reference

Complete reference for all available tools in Ferrum MCP Server.

## Table of Contents

- [Navigation Tools](#navigation-tools)
- [Interaction Tools](#interaction-tools)
- [Extraction Tools](#extraction-tools)
- [Waiting Tools](#waiting-tools)
- [Advanced Tools](#advanced-tools)

---

## Navigation Tools

### navigate

Navigate to a specific URL.

**Parameters:**
- `url` (string, required): The URL to navigate to (must include protocol)

**Example:**
```json
{
  "name": "navigate",
  "arguments": {
    "url": "https://example.com"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "url": "https://example.com",
    "title": "Example Domain"
  }
}
```

---

### go_back

Go back to the previous page in browser history.

**Parameters:** None

**Example:**
```json
{
  "name": "go_back",
  "arguments": {}
}
```

---

### go_forward

Go forward to the next page in browser history.

**Parameters:** None

**Example:**
```json
{
  "name": "go_forward",
  "arguments": {}
}
```

---

### refresh

Refresh the current page.

**Parameters:** None

**Example:**
```json
{
  "name": "refresh",
  "arguments": {}
}
```

---

## Interaction Tools

### click

Click on an element using a CSS selector.

**Parameters:**
- `selector` (string, required): CSS selector of the element to click
- `wait` (number, optional): Seconds to wait for element (default: 5)

**Example:**
```json
{
  "name": "click",
  "arguments": {
    "selector": "button.submit",
    "wait": 10
  }
}
```

---

### fill_form

Fill one or more form fields with values.

**Parameters:**
- `fields` (array, required): Array of field objects
  - `selector` (string): CSS selector of the field
  - `value` (string): Value to fill

**Example:**
```json
{
  "name": "fill_form",
  "arguments": {
    "fields": [
      {"selector": "#email", "value": "user@example.com"},
      {"selector": "#password", "value": "secret123"}
    ]
  }
}
```

---

### press_key

Press keyboard keys.

**Parameters:**
- `key` (string, required): Key to press (Enter, Tab, Escape, ArrowDown, etc.)
- `selector` (string, optional): CSS selector to focus before pressing key

**Example:**
```json
{
  "name": "press_key",
  "arguments": {
    "key": "Enter",
    "selector": "input#search"
  }
}
```

---

### hover

Hover over an element.

**Parameters:**
- `selector` (string, required): CSS selector of the element to hover over

**Example:**
```json
{
  "name": "hover",
  "arguments": {
    "selector": ".dropdown-trigger"
  }
}
```

---

## Extraction Tools

### get_text

Extract text content from one or more elements.

**Parameters:**
- `selector` (string, required): CSS selector of element(s)
- `multiple` (boolean, optional): Extract from all matching elements (default: false)

**Example:**
```json
{
  "name": "get_text",
  "arguments": {
    "selector": "h1",
    "multiple": false
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "text": "Welcome to Example"
  }
}
```

---

### get_html

Get HTML content of the page or a specific element.

**Parameters:**
- `selector` (string, optional): CSS selector to get HTML of specific element

**Example:**
```json
{
  "name": "get_html",
  "arguments": {
    "selector": "article.main"
  }
}
```

---

### screenshot

Take a screenshot of the page or a specific element.

**Parameters:**
- `selector` (string, optional): CSS selector to screenshot specific element
- `full_page` (boolean, optional): Capture full scrollable page (default: false)
- `format` (string, optional): Image format - "png" or "jpeg" (default: "png")

**Example:**
```json
{
  "name": "screenshot",
  "arguments": {
    "full_page": true,
    "format": "png"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "screenshot": "iVBORw0KGgoAAAANS...",
    "format": "png",
    "encoding": "base64"
  }
}
```

---

### get_title

Get the title of the current page.

**Parameters:** None

**Example:**
```json
{
  "name": "get_title",
  "arguments": {}
}
```

---

### get_url

Get the current URL of the page.

**Parameters:** None

**Example:**
```json
{
  "name": "get_url",
  "arguments": {}
}
```

---

## Waiting Tools

### wait_for_element

Wait for an element to appear on the page.

**Parameters:**
- `selector` (string, required): CSS selector of the element to wait for
- `timeout` (number, optional): Maximum seconds to wait (default: 30)
- `state` (string, optional): Wait for element to be "visible", "hidden", or "exists" (default: "visible")

**Example:**
```json
{
  "name": "wait_for_element",
  "arguments": {
    "selector": ".loading-complete",
    "timeout": 30,
    "state": "visible"
  }
}
```

---

### wait_for_navigation

Wait for page navigation to complete.

**Parameters:**
- `timeout` (number, optional): Maximum seconds to wait (default: 30)
- `wait_until` (string, optional): When to consider navigation complete - "load", "domcontentloaded", or "networkidle" (default: "load")

**Example:**
```json
{
  "name": "wait_for_navigation",
  "arguments": {
    "timeout": 30,
    "wait_until": "networkidle"
  }
}
```

---

### wait

Wait for a specific number of seconds.

**Parameters:**
- `seconds` (number, required): Number of seconds to wait (min: 0.1, max: 60)

**Example:**
```json
{
  "name": "wait",
  "arguments": {
    "seconds": 2.5
  }
}
```

---

## Advanced Tools

### execute_script

Execute JavaScript code in the browser context.

**Parameters:**
- `script` (string, required): JavaScript code to execute

**Example:**
```json
{
  "name": "execute_script",
  "arguments": {
    "script": "document.body.style.backgroundColor = 'red';"
  }
}
```

---

### evaluate_js

Evaluate JavaScript expression and return the result.

**Parameters:**
- `expression` (string, required): JavaScript expression to evaluate

**Example:**
```json
{
  "name": "evaluate_js",
  "arguments": {
    "expression": "document.title"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "result": "Example Domain"
  }
}
```

---

### get_cookies

Get all cookies or cookies for a specific domain.

**Parameters:**
- `domain` (string, optional): Filter cookies by domain

**Example:**
```json
{
  "name": "get_cookies",
  "arguments": {
    "domain": "example.com"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "cookies": [
      {
        "name": "session",
        "value": "abc123",
        "domain": ".example.com",
        "path": "/"
      }
    ],
    "count": 1
  }
}
```

---

### set_cookie

Set a cookie in the browser.

**Parameters:**
- `name` (string, required): Cookie name
- `value` (string, required): Cookie value
- `domain` (string, required): Cookie domain
- `path` (string, optional): Cookie path (default: "/")
- `secure` (boolean, optional): Secure flag (default: false)
- `httponly` (boolean, optional): HttpOnly flag (default: false)

**Example:**
```json
{
  "name": "set_cookie",
  "arguments": {
    "name": "session",
    "value": "xyz789",
    "domain": ".example.com",
    "path": "/",
    "secure": true,
    "httponly": true
  }
}
```

---

### clear_cookies

Clear all cookies or cookies for a specific domain.

**Parameters:**
- `domain` (string, optional): Clear cookies only for this domain

**Example:**
```json
{
  "name": "clear_cookies",
  "arguments": {
    "domain": "example.com"
  }
}
```

---

### get_attribute

Get attribute value from an element.

**Parameters:**
- `selector` (string, required): CSS selector of the element
- `attribute` (string, required): Attribute name to get

**Example:**
```json
{
  "name": "get_attribute",
  "arguments": {
    "selector": "a.download",
    "attribute": "href"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "selector": "a.download",
    "attribute": "href",
    "value": "https://example.com/file.pdf"
  }
}
```

---

## Error Responses

All tools return errors in this format:

```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

Common errors:
- `"Browser is not active"` - Browser needs to be started
- `"Element not found: <selector>"` - CSS selector didn't match any element
- `"Failed to navigate: <reason>"` - Navigation failed
- `"Timeout waiting for element"` - Element didn't appear within timeout
