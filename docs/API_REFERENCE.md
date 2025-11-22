# FerrumMCP API Reference

Comprehensive documentation for all FerrumMCP browser automation tools.

## Table of Contents

- [Overview](#overview)
- [Important Notes](#important-notes)
- [Session Management](#session-management)
  - [create_session](#create_session)
  - [list_sessions](#list_sessions)
  - [get_session_info](#get_session_info)
  - [close_session](#close_session)
- [Navigation](#navigation)
  - [navigate](#navigate)
  - [go_back](#go_back)
  - [go_forward](#go_forward)
  - [refresh](#refresh)
- [Interaction](#interaction)
  - [click](#click)
  - [fill_form](#fill_form)
  - [press_key](#press_key)
  - [hover](#hover)
  - [drag_and_drop](#drag_and_drop)
  - [accept_cookies](#accept_cookies)
  - [solve_captcha](#solve_captcha)
- [Extraction](#extraction)
  - [get_text](#get_text)
  - [get_html](#get_html)
  - [screenshot](#screenshot)
  - [get_title](#get_title)
  - [get_url](#get_url)
  - [find_by_text](#find_by_text)
- [Advanced](#advanced)
  - [execute_script](#execute_script)
  - [evaluate_js](#evaluate_js)
  - [get_cookies](#get_cookies)
  - [set_cookie](#set_cookie)
  - [clear_cookies](#clear_cookies)
  - [get_attribute](#get_attribute)
  - [query_shadow_dom](#query_shadow_dom)
- [Waiting (Currently Disabled)](#waiting-currently-disabled)
  - [wait_for_element](#wait_for_element)
  - [wait_for_navigation](#wait_for_navigation)
  - [wait](#wait)

---

## Overview

FerrumMCP provides 27+ browser automation tools through the Model Context Protocol (MCP). All tools return responses in a standardized JSON format with a `success` boolean and either `data` or `error` fields.

## Important Notes

1. **Session-Based Architecture**: All browser operation tools (except session management tools) require a valid `session_id` parameter
2. **Session Creation**: You must create a session using `create_session` before using any browser automation tools
3. **Session Lifecycle**: Sessions auto-close after 30 minutes of inactivity or can be manually closed with `close_session`
4. **Multiple Sessions**: You can run multiple concurrent browser sessions with different configurations
5. **Screenshot Format**: The `screenshot` tool returns base64-encoded image data
6. **Selector Support**: Most tools support both CSS selectors and XPath (use `xpath:` prefix for XPath)

---

## Session Management

### create_session

Create a new browser session with custom options. Returns a `session_id` to use with other tools.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| browser_id | string | No | Browser ID from `ferrum://browsers` resource |
| user_profile_id | string | No | User profile ID from `ferrum://user-profiles` resource |
| bot_profile_id | string | No | BotBrowser profile ID from `ferrum://bot-profiles` resource |
| browser_path | string | No | Path to browser executable (legacy) |
| botbrowser_profile | string | No | Path to BotBrowser profile (legacy) |
| headless | boolean | No | Run in headless mode (default: false) |
| timeout | number | No | Browser timeout in seconds (default: 60) |
| browser_options | object | No | Additional browser options (e.g., `{"--window-size": "1920,1080"}`) |
| metadata | object | No | Custom metadata for this session |

**Example Request:**

```json
{
  "name": "create_session",
  "arguments": {
    "headless": true,
    "timeout": 60,
    "browser_options": {
      "--window-size": "1920,1080"
    },
    "metadata": {
      "user": "john",
      "project": "scraping"
    }
  }
}
```

**Example Response:**

```json
{
  "session_id": "uuid-1234-5678",
  "message": "Session created successfully",
  "options": {
    "headless": true,
    "timeout": 60,
    "browser_options": {
      "--window-size": "1920,1080"
    }
  }
}
```

**Notes:**
- Use `browser_id`, `user_profile_id`, and `bot_profile_id` for resource-based configuration (recommended)
- Legacy `browser_path` and `botbrowser_profile` parameters still supported
- Query `ferrum://browsers` and `ferrum://bot-profiles` resources to discover available configurations

---

### list_sessions

List all active browser sessions with their information.

**Parameters:**

None.

**Example Request:**

```json
{
  "name": "list_sessions",
  "arguments": {}
}
```

**Example Response:**

```json
{
  "count": 2,
  "sessions": [
    {
      "id": "uuid-1234",
      "status": "active",
      "browser_type": "chrome",
      "headless": true,
      "created_at": "2025-11-22T10:00:00Z",
      "last_used_at": "2025-11-22T10:05:00Z",
      "uptime_seconds": 300
    },
    {
      "id": "uuid-5678",
      "status": "active",
      "browser_type": "botbrowser",
      "headless": false,
      "created_at": "2025-11-22T10:10:00Z",
      "last_used_at": "2025-11-22T10:15:00Z",
      "uptime_seconds": 300
    }
  ]
}
```

---

### get_session_info

Get detailed information about a specific browser session.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | No | Session ID (omit for default session) |

**Example Request:**

```json
{
  "name": "get_session_info",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "id": "uuid-1234",
  "status": "active",
  "browser_type": "chrome",
  "headless": true,
  "timeout": 60,
  "created_at": "2025-11-22T10:00:00Z",
  "last_used_at": "2025-11-22T10:05:00Z",
  "uptime_seconds": 300,
  "metadata": {
    "user": "john",
    "project": "scraping"
  }
}
```

---

### close_session

Close a specific browser session. The browser will be stopped and the session removed.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | ID of the session to close |

**Example Request:**

```json
{
  "name": "close_session",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "session_id": "uuid-1234",
  "message": "Session closed successfully"
}
```

---

## Navigation

### navigate

Navigate to a specific URL in the browser.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| url | string | Yes | URL to navigate to (must include http:// or https://) |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "navigate",
  "arguments": {
    "url": "https://example.com",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "url": "https://example.com",
  "title": "Example Domain"
}
```

**Notes:**
- URL must start with `http://` or `https://`
- Automatically waits for network to be idle after navigation
- Throws timeout error if navigation takes longer than browser timeout

---

### go_back

Go back to the previous page in browser history.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "go_back",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "url": "https://previous-page.com",
  "title": "Previous Page"
}
```

**Notes:**
- Waits for network to be idle after navigation
- Returns current URL and title after going back

---

### go_forward

Go forward to the next page in browser history.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "go_forward",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "url": "https://next-page.com",
  "title": "Next Page"
}
```

**Notes:**
- Waits for network to be idle after navigation
- Returns current URL and title after going forward

---

### refresh

Refresh the current page.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "refresh",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "url": "https://example.com",
  "title": "Example Domain"
}
```

**Notes:**
- Waits for network to be idle after refresh
- Returns current URL and title

---

## Interaction

### click

Click on an element using a CSS selector or XPath.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector or XPath (use `xpath:` prefix for XPath) |
| wait | number | No | Seconds to wait for element (default: 5) |
| force | boolean | No | Force click even if hidden/not visible (default: false) |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "click",
  "arguments": {
    "selector": "button.submit",
    "wait": 10,
    "force": false,
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Clicked on button.submit"
}
```

**Notes:**
- Supports both CSS selectors and XPath (use `xpath://button[@id='submit']`)
- Automatically scrolls element into view before clicking
- If `force: true`, uses JavaScript click as fallback for hidden elements
- Includes retry logic for stale elements

---

### fill_form

Fill one or more form fields with values.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| fields | array | Yes | Array of field objects with `selector` and `value` |
| session_id | string | Yes | Session ID to use |

**Field Object:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector of the field |
| value | string | Yes | Value to fill |

**Example Request:**

```json
{
  "name": "fill_form",
  "arguments": {
    "fields": [
      {
        "selector": "input[name='username']",
        "value": "john_doe"
      },
      {
        "selector": "input[name='password']",
        "value": "secret123"
      }
    ],
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "fields": [
    {
      "selector": "input[name='username']",
      "filled": true
    },
    {
      "selector": "input[name='password']",
      "filled": true
    }
  ]
}
```

**Notes:**
- Automatically scrolls fields into view
- Focuses each field before typing
- Includes small delays between fields for validation/autocomplete handlers
- Uses retry logic for stale elements

---

### press_key

Press keyboard keys (e.g., Enter, Tab, Escape).

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| key | string | Yes | Key to press (Enter, Tab, Escape, ArrowDown, etc.) |
| selector | string | No | CSS selector to focus before pressing key |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "press_key",
  "arguments": {
    "key": "Enter",
    "selector": "input.search",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Pressed key: Enter"
}
```

**Supported Keys:**
- `Enter`, `Return`
- `Tab`
- `Escape`, `Esc`
- `Backspace`
- `Delete`, `Del`
- `ArrowDown`, `Down`
- `ArrowUp`, `Up`
- `ArrowLeft`, `Left`
- `ArrowRight`, `Right`
- `Space`

---

### hover

Hover over an element using a CSS selector.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector of the element |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "hover",
  "arguments": {
    "selector": ".dropdown-menu",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Hovered over .dropdown-menu"
}
```

**Notes:**
- Automatically scrolls element into view
- Falls back to JavaScript hover if native hover fails

---

### drag_and_drop

Drag an element and drop it onto another element or coordinates.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| source_selector | string | Yes | CSS selector or XPath of element to drag |
| target_selector | string | No | CSS selector or XPath of drop target |
| target_x | number | No | X coordinate to drop at |
| target_y | number | No | Y coordinate to drop at |
| steps | number | No | Number of steps for smooth dragging (default: 10) |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "drag_and_drop",
  "arguments": {
    "source_selector": ".draggable-item",
    "target_selector": ".drop-zone",
    "steps": 15,
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Dragged from (100, 200) to (500, 300)"
}
```

**Notes:**
- Either `target_selector` or both `target_x` and `target_y` must be provided
- Supports both CSS selectors and XPath
- Performs smooth drag with configurable steps
- Includes delays to ensure drag events register properly

---

### accept_cookies

Automatically detect and accept cookie consent banners.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| wait | number | No | Seconds to wait for banner to appear (default: 3) |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "accept_cookies",
  "arguments": {
    "wait": 5,
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "Cookie consent accepted successfully",
  "strategy": "common_frameworks",
  "selector": "#onetrust-accept-btn-handler"
}
```

**Detection Strategies (in order):**
1. **Common Frameworks**: OneTrust, Cookiebot, Osano, Quantcast, TrustArc, Termly, Didomi, Sourcepoint
2. **Iframe Detection**: Checks iframes for cookie banners
3. **Text-Based Detection**: Searches for common accept button text in multiple languages
4. **CSS Selectors**: Generic CSS patterns for accept buttons

**Supported Languages:**
- English, French, German, Spanish, Italian, Portuguese

**Notes:**
- Automatically tries multiple strategies
- Filters out reject/customize buttons
- Works with both main page and iframes
- Returns the strategy and selector used for success

---

### solve_captcha

Automatically detect and solve audio CAPTCHA challenges using Whisper speech recognition.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "solve_captcha",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "message": "CAPTCHA solved successfully",
  "transcription": "the quick brown fox",
  "audio_button": "#recaptcha-audio-button",
  "input_field": "#audio-response",
  "verify_button": "#recaptcha-verify-button"
}
```

**Process:**
1. Detects and clicks CAPTCHA checkbox (if present)
2. Finds and clicks audio challenge button
3. Downloads audio challenge
4. Transcribes audio using Whisper
5. Fills input field with transcription
6. Clicks verify button

**Supported CAPTCHAs:**
- Google reCAPTCHA
- hCaptcha

**Notes:**
- Requires Whisper service to be available
- Works with both main page and iframes
- Uses human-like typing delays
- Automatically cleans up temporary audio files

---

## Extraction

### get_text

Extract text content from one or more elements.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector or XPath (use `xpath:` prefix) |
| multiple | boolean | No | Extract from all matching elements (default: false) |
| session_id | string | Yes | Session ID to use |

**Example Request (Single Element):**

```json
{
  "name": "get_text",
  "arguments": {
    "selector": "h1.title",
    "session_id": "uuid-1234"
  }
}
```

**Example Response (Single):**

```json
{
  "text": "Welcome to Example"
}
```

**Example Request (Multiple Elements):**

```json
{
  "name": "get_text",
  "arguments": {
    "selector": "li.item",
    "multiple": true,
    "session_id": "uuid-1234"
  }
}
```

**Example Response (Multiple):**

```json
{
  "texts": [
    "First item",
    "Second item",
    "Third item"
  ],
  "count": 3
}
```

**Notes:**
- Supports both CSS selectors and XPath
- Returns array when `multiple: true`
- Throws error if no elements found

---

### get_html

Get HTML content of the page or a specific element.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | No | CSS selector to get HTML of specific element |
| session_id | string | Yes | Session ID to use |

**Example Request (Full Page):**

```json
{
  "name": "get_html",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response (Full Page):**

```json
{
  "html": "<!DOCTYPE html><html>...</html>",
  "url": "https://example.com"
}
```

**Example Request (Specific Element):**

```json
{
  "name": "get_html",
  "arguments": {
    "selector": "div.content",
    "session_id": "uuid-1234"
  }
}
```

**Example Response (Element):**

```json
{
  "html": "<div class=\"content\">...</div>",
  "selector": "div.content"
}
```

**Notes:**
- Omit `selector` to get full page HTML
- Returns `outerHTML` for specific elements (includes the element itself)

---

### screenshot

Take a screenshot of the page or a specific element.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | No | CSS selector to screenshot specific element |
| full_page | boolean | No | Capture full scrollable page (default: false) |
| format | string | No | Image format: `png` or `jpeg` (default: png) |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "screenshot",
  "arguments": {
    "full_page": true,
    "format": "png",
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "type": "image",
  "data": "iVBORw0KGgoAAAANSUhEUgAA...(base64 data)...",
  "mime_type": "image/png"
}
```

**Notes:**
- Returns base64-encoded image data
- Automatically resizes if dimensions exceed 8000px (Claude API limit)
- Uses high-quality Lanczos3 interpolation for resizing
- Scrolls element into view before screenshot if selector provided

---

### get_title

Get the title of the current page.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "get_title",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "title": "Example Domain",
  "url": "https://example.com"
}
```

---

### get_url

Get the current URL of the page.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "get_url",
  "arguments": {
    "session_id": "uuid-1234"
  }
}
```

**Example Response:**

```json
{
  "url": "https://example.com/page"
}
```

---

### find_by_text

Find elements by their text content using XPath.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| text | string | Yes | Text to search for |
| tag | string | No | HTML tag to search within (default: `*` for any) |
| exact | boolean | No | Exact match vs partial match (default: false) |
| multiple | boolean | No | Return all matches or first visible (default: false) |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{
  "name": "find_by_text",
  "arguments": {
    "text": "Sign In",
    "tag": "button",
    "exact": false,
    "session_id": "uuid-1234"
  }
}
```

**Example Response (Single):**

```json
{
  "tag": "button",
  "text": "Sign In",
  "visible": true,
  "selector": "button.login-btn",
  "xpath": "//button[contains(normalize-space(.), 'sign in')]",
  "total_found": 3
}
```

**Example Response (Multiple):**

```json
{
  "found": 3,
  "elements": [
    {
      "index": 0,
      "tag": "button",
      "text": "Sign In",
      "visible": true,
      "selector": "button#main-login"
    },
    {
      "index": 1,
      "tag": "a",
      "text": "Sign In Here",
      "visible": true,
      "selector": "a.secondary-login"
    }
  ],
  "xpath": "//button[contains(normalize-space(.), 'sign in')]"
}
```

**Notes:**
- Case-insensitive search
- Handles quotes in text properly (prevents XPath injection)
- Prefers visible elements when `multiple: false`
- Generates CSS selector from element id/classes when possible

---

## Advanced

### execute_script

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

---

### evaluate_js

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

---

### get_cookies

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

---

### set_cookie

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

---

### clear_cookies

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

---

### get_attribute

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

---

### query_shadow_dom

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

---

## Response Format

All tools return responses in this standard format:

**Success Response:**

```json
{
  "success": true,
  "data": {
    // Tool-specific data
  }
}
```

**Error Response:**

```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

**Image Response (screenshot tool):**

```json
{
  "type": "image",
  "data": "base64-encoded-image-data",
  "mime_type": "image/png"
}
```

---

## Common Error Scenarios

1. **Missing session_id**: "session_id is required. Create a session first using create_session tool."
2. **Invalid session**: "Session not found: {session_id}"
3. **Element not found**: "Element not found: {selector}"
4. **Timeout errors**: "Navigation timed out" / "Timeout waiting for element"
5. **JavaScript errors**: "Failed to execute script: {error}"

---

## Best Practices

1. **Always create a session first**: Use `create_session` before any browser operations
2. **Use resource discovery**: Query `ferrum://browsers` and `ferrum://bot-profiles` to see available configurations
3. **Handle sessions properly**: Close sessions when done to free resources
4. **Use appropriate selectors**: Prefer CSS selectors for performance, XPath for complex queries
5. **Set timeouts wisely**: Increase timeout for slow-loading pages
6. **Force clicks sparingly**: Only use `force: true` when necessary, as it bypasses visibility checks
7. **Screenshot optimization**: Use `jpeg` format for smaller file sizes when quality is not critical

---

For more information, see:
- [Getting Started Guide](GETTING_STARTED.md)
- [Configuration Guide](CONFIGURATION.md)
- [Project Documentation](../CLAUDE.md)
