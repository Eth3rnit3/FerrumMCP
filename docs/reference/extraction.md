# Extraction

## snapshot

Compact, agent-friendly view of the page: interactive elements (links, buttons, inputs, selects, custom roles) and headings, each with a **stable ref** that every other tool accepts as selector (`ref:e12`). Far cheaper than `get_html` for deciding what to do next.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| mode | string | No | `interactive` (default) or `full` (adds images, labels, paragraphs, alerts) |
| selector | string | No | Restrict the snapshot to a subtree |
| include_hidden | boolean | No | Include hidden elements (default: false) |
| max_elements | integer | No | Maximum number of elements (default: 200) |
| format | string | No | `text` (default) or `json` |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{ "name": "snapshot", "arguments": { "session_id": "uuid-1234" } }
```

**Example Response (text):**

```json
{
  "url": "https://example.com/signup",
  "title": "Sign up",
  "count": 6,
  "total": 6,
  "truncated": false,
  "snapshot": "[e1] heading(1) \"Create your account\"\n[e2] textbox \"Email address\" type=email placeholder=\"you@example.com\"\n[e3] checkbox \"newsletter\" checked\n[e4] combobox \"plan\"\n[e5] button \"Create account\"\n[e6] link \"Documentation\" href=/docs"
}
```

**Example Response (json):** `elements` is an array of `{ ref, role, tag, name, selector, href?, type?, placeholder?, value?, checked?, disabled?, level? }`.

**Notes:**
- When a CAPTCHA widget is on the page, the response carries `"captcha": ["turnstile"]` (also `recaptcha`, `hcaptcha`) and the text snapshot starts with `CAPTCHA detected: turnstile (solve_captcha)`
- Refs are stored on the elements (`data-fmcp-ref`) and stay stable across snapshots until the page navigates
- Typical loop: `snapshot` → `click ref:e5` → `wait_for_text` → `snapshot`
- Names follow accessibility rules: `aria-label`, `<label for>`, placeholder, name, then visible text
- Radio buttons also show their `value`, so unlabeled buttons of one group stay distinguishable

## get_text

Extract text content from one or more elements.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector, XPath (`xpath:` prefix) or snapshot ref |
| multiple | boolean | No | Extract from all matching elements (default: false) |
| wait | number | No | Seconds to wait for the element (default: 5) |
| raw | boolean | No | Return the text exactly as in the DOM (default: false, whitespace is collapsed and trimmed) |
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

## get_html

Get HTML content of the page or a specific element.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | No | Selector of the element to get the outerHTML of |
| max_length | integer | No | Truncate the HTML to this many characters (response has `truncated: true`) |
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

## screenshot

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

## get_title

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

## get_url

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

## find_by_text

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

