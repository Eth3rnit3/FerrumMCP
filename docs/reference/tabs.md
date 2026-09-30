# Tabs & Viewport

Tools operate on the session's **current tab**. Links with `target="_blank"` open new tabs that you can activate with `switch_tab`.

## list_tabs

**Example Response:**

```json
{
  "count": 2,
  "tabs": [
    { "index": 0, "tab_id": "A1B2...", "url": "https://example.com/", "title": "Example", "current": false },
    { "index": 1, "tab_id": "C3D4...", "url": "https://example.com/help", "title": "Help", "current": true }
  ]
}
```

## new_tab

Open a new tab (optionally at a URL) and make it current.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| url | string | No | URL to open (subject to the navigation policy) |
| session_id | string | Yes | Session ID to use |

## switch_tab

Make another tab current, by `tab_id` (from `list_tabs`) or zero-based `index`.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| tab_id | string | No | Tab to activate |
| index | integer | No | Zero-based index (alternative to tab_id) |
| session_id | string | Yes | Session ID to use |

## close_tab

Close a tab (the current one by default). The last remaining tab cannot be closed; closing the current tab activates the first remaining one.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| tab_id | string | No | Tab to close (default: current) |
| index | integer | No | Zero-based index (alternative to tab_id) |
| session_id | string | Yes | Session ID to use |

## set_viewport

| Name | Type | Required | Description |
|------|------|----------|-------------|
| width | integer | Yes | Viewport width in pixels |
| height | integer | Yes | Viewport height in pixels |
| scale_factor | number | No | Device scale factor (0 keeps the default) |
| mobile | boolean | No | Emulate a mobile device (default: false) |
| session_id | string | Yes | Session ID to use |

