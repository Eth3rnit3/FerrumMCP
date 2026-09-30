# Navigation

## navigate

Navigate to a specific URL in the browser.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| url | string | Yes | URL to navigate to (must include http:// or https://) |
| wait_for_idle | boolean | No | Wait for the network to settle after navigation (default: true) |
| timeout | number | No | Seconds to wait for network idle (default: 30) |
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
- Automatically waits for network to be idle after navigation (disable with `wait_for_idle: false` for pages that stream forever)
- Refused when the host is denied by `ALLOWED_HOSTS` / `BLOCKED_HOSTS` (see the Configuration Guide)
- Throws timeout error if navigation takes longer than browser timeout

## go_back

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

## go_forward

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

## refresh

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

