# Session Management

## create_session

Create a new browser session with custom options. Returns a `session_id` to use with other tools.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| browser_id | string | No | Browser ID from `ferrum://browsers` resource |
| user_profile_id | string | No | User profile ID from `ferrum://user-profiles` resource |
| bot_profile_id | string | No | BotBrowser profile ID from `ferrum://bot-profiles` resource |
| browser_path | string | No | Path to browser executable (legacy) |
| botbrowser_profile | string | No | Path to BotBrowser profile (legacy) |
| headless | boolean | No | Run in headless mode (default: `BROWSER_HEADLESS`) |
| timeout | number | No | Browser timeout in seconds (default: 60) |
| browser_options | object | No | Extra Chrome flags without the leading dashes (e.g., `{"window-size": "1920,1080", "lang": "fr-FR"}`) |
| metadata | object | No | Custom metadata for this session |

**Example Request:**

```json
{
  "name": "create_session",
  "arguments": {
    "headless": true,
    "timeout": 60,
    "browser_options": {
      "window-size": "1920,1080"
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
      "window-size": "1920,1080"
    }
  }
}
```

**Notes:**
- Use `browser_id`, `user_profile_id`, and `bot_profile_id` for resource-based configuration (recommended)
- Legacy `browser_path` and `botbrowser_profile` parameters still supported
- Query `ferrum://browsers` and `ferrum://bot-profiles` resources to discover available configurations

## list_sessions

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

## get_session_info

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

## close_session

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

