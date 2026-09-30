# Waiting

## wait_for_selector

Wait until an element reaches a state.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector, XPath or snapshot ref |
| state | string | No | `visible` (default), `hidden`, `attached`, `detached` |
| timeout | number | No | Maximum seconds to wait (default: 10) |
| session_id | string | Yes | Session ID to use |

**Example Response:**

```json
{ "found": true, "state": "visible", "selector": "#results", "elapsed_ms": 640 }
```

On timeout the tool fails with `Timed out after 10s waiting for #results to be visible`.

## wait_for_text

Wait until text is visible on the page (optionally inside an element).

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| text | string | Yes | Text to wait for |
| selector | string | No | CSS selector of the element to search in (default: body) |
| exact | boolean | No | Match the whole text exactly (default: substring) |
| timeout | number | No | Maximum seconds to wait (default: 10) |
| session_id | string | Yes | Session ID to use |

## wait_for_network_idle

Wait until the page has no pending requests (after a click that triggers XHR/fetch, for instance).

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| timeout | number | No | Maximum seconds to wait (default: 30) |
| connections | integer | No | Pending connections tolerated as idle (default: 0) |
| session_id | string | Yes | Session ID to use |

**Example Response:**

```json
{ "idle": true, "elapsed_ms": 120, "url": "https://example.com/results" }
```

