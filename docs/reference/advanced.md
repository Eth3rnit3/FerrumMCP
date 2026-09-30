# Advanced

## execute_script

Execute JavaScript code in the browser context (for side effects, no return value).

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| script | string | Yes | JavaScript code to execute |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "execute_script",
  "arguments": {
    "script": "document.body.style.backgroundColor = 'red';",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Script executed successfully"
}
```

**Notes:**
- Use `execute_script` for side effects (DOM manipulation, etc.)
- Use `evaluate_js` if you need to get a return value
- Script runs in page context with access to DOM

## evaluate_js

Evaluate JavaScript expression and return the result.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| expression | string | Yes | JavaScript expression to evaluate |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "evaluate_js",
  "arguments": {
    "expression": "document.querySelectorAll('p').length",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "result": 42
}
```

**Notes:**
- Returns the result of the expression
- Can return primitives, arrays, or objects
- Use `execute_script` for code without return values

## get_cookies

Get all cookies or cookies for a specific domain.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| domain | string | No | Filter cookies by domain |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "get_cookies",
  "arguments": {
    "domain": "example.com",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "cookies": [
    {
      "name": "session_id",
      "value": "abc123",
      "domain": ".example.com",
      "path": "/",
      "secure": true,
      "httpOnly": true
    }
  ],
  "count": 1
}
```

**Notes:**
- Omit `domain` to get all cookies
- Returns structured cookie data with all attributes

## set_cookie

Set a cookie in the browser.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| name | string | Yes | Cookie name |
| value | string | Yes | Cookie value |
| domain | string | Yes | Cookie domain |
| path | string | No | Cookie path (default: /) |
| secure | boolean | No | Secure flag (default: false) |
| httponly | boolean | No | HttpOnly flag (default: false) |
| expires | integer | No | Expiry as a Unix timestamp in seconds |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "set_cookie",
  "arguments": {
    "name": "user_pref",
    "value": "dark_mode",
    "domain": ".example.com",
    "path": "/",
    "secure": true,
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Cookie set: user_pref"
}
```

## clear_cookies

Clear all cookies or cookies for a specific domain.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| domain | string | No | Clear cookies only for this domain |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "clear_cookies",
  "arguments": {
    "domain": "example.com",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Cleared 5 cookies for example.com"
}
```

**Notes:**
- Omit `domain` to clear all cookies

## get_attribute

Get attribute value(s) from an element.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector of the element |
| attribute | string | Yes | Attribute name to get |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "get_attribute",
  "arguments": {
    "selector": "a.download",
    "attribute": "href",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "selector": "a.download",
  "attribute": "href",
  "value": "https://example.com/file.pdf"
}
```

## query_shadow_dom

Query and interact with elements inside Shadow DOM.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| host_selector | string | Yes | CSS selector of Shadow DOM host element |
| shadow_selector | string | Yes | CSS selector to find element(s) within Shadow DOM |
| action | string | Yes | Action: `click`, `get_text`, `get_html`, or `get_attribute` |
| attribute | string | No | Attribute name (required when action is `get_attribute`) |
| multiple | boolean | No | Return all matching elements (default: false) |
| session_id | string | Yes | Session ID to use |

**Example Request (Click):**

```json
{
  "name": "query_shadow_dom",
  "arguments": {
    "host_selector": "video-player",
    "shadow_selector": "button.play",
    "action": "click",
    "session_id": "uuid-1234"
  }
}
```

**Example Response (Click):**

```json
{
  "message": "Clicked element in Shadow DOM: button.play"
}
```

**Example Request (Get Text):**

```json
{
  "name": "query_shadow_dom",
  "arguments": {
    "host_selector": "custom-widget",
    "shadow_selector": ".status",
    "action": "get_text",
    "session_id": "uuid-1234"
  }
}
```

**Example Response (Get Text):**

```json
{
  "text": "Online"
}
```

**Notes:**
- Essential for interacting with Web Components
- Supports all standard actions: click, text extraction, HTML, attributes
- Can query multiple elements with `multiple: true`

