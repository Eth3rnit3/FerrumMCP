# API Reference

FerrumMCP provides 40 browser automation tools through the Model Context Protocol (MCP). All tools return responses in a standardized JSON format with a `success` boolean and either `data` or `error` fields.

## Important Notes

1. **Session-Based Architecture**: All browser operation tools (except session management tools) require a valid `session_id` parameter
2. **Session Creation**: You must create a session using `create_session` before using any browser automation tools
3. **Session Lifecycle**: Sessions auto-close after 30 minutes of inactivity or can be manually closed with `close_session`
4. **Multiple Sessions**: You can run multiple concurrent browser sessions with different configurations
5. **Screenshot Format**: The `screenshot` tool returns base64-encoded image data
6. **Selector Support**: Every element-based tool accepts a CSS selector, an XPath (`xpath:` prefix or starting with `//`) or a snapshot ref (`ref:e12`, see [snapshot](./extraction#snapshot))
7. **Tabs**: tools act on the session's current tab; use [new_tab](./tabs#new_tab) / [switch_tab](./tabs#switch_tab) to change it

## Tools

| Category | Tools |
|---|---|
| [Session Management](./sessions) | [`create_session`](./sessions#create_session) [`list_sessions`](./sessions#list_sessions) [`get_session_info`](./sessions#get_session_info) [`close_session`](./sessions#close_session) |
| [Navigation](./navigation) | [`navigate`](./navigation#navigate) [`go_back`](./navigation#go_back) [`go_forward`](./navigation#go_forward) [`refresh`](./navigation#refresh) |
| [Interaction](./interaction) | [`click`](./interaction#click) [`fill_form`](./interaction#fill_form) [`press_key`](./interaction#press_key) [`hover`](./interaction#hover) [`drag_and_drop`](./interaction#drag_and_drop) [`scroll`](./interaction#scroll) [`select_option`](./interaction#select_option) [`upload_file`](./interaction#upload_file) [`accept_cookies`](./interaction#accept_cookies) [`solve_captcha`](./interaction#solve_captcha) |
| [Extraction](./extraction) | [`snapshot`](./extraction#snapshot) [`get_text`](./extraction#get_text) [`get_html`](./extraction#get_html) [`screenshot`](./extraction#screenshot) [`get_title`](./extraction#get_title) [`get_url`](./extraction#get_url) [`find_by_text`](./extraction#find_by_text) |
| [Waiting](./waiting) | [`wait_for_selector`](./waiting#wait_for_selector) [`wait_for_text`](./waiting#wait_for_text) [`wait_for_network_idle`](./waiting#wait_for_network_idle) |
| [Tabs & Viewport](./tabs) | [`list_tabs`](./tabs#list_tabs) [`new_tab`](./tabs#new_tab) [`switch_tab`](./tabs#switch_tab) [`close_tab`](./tabs#close_tab) [`set_viewport`](./tabs#set_viewport) |
| [Advanced](./advanced) | [`execute_script`](./advanced#execute_script) [`evaluate_js`](./advanced#evaluate_js) [`get_cookies`](./advanced#get_cookies) [`set_cookie`](./advanced#set_cookie) [`clear_cookies`](./advanced#clear_cookies) [`get_attribute`](./advanced#get_attribute) [`query_shadow_dom`](./advanced#query_shadow_dom) |

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

## Common Error Scenarios

1. **Missing session_id**: "session_id is required. Create a session first using create_session tool."
2. **Invalid session**: "Session not found: {session_id}"
3. **Element not found**: "Element not found: {selector}"
4. **Timeout errors**: "Navigation timed out" / "Timed out after 10s waiting for #x to be visible"
5. **Any other tool failure**: "{tool_name} failed: {error}" (e.g. "execute_script failed: ReferenceError: foo is not defined")

## Best Practices

1. **Always create a session first**: Use `create_session` before any browser operations
2. **Use resource discovery**: Query `ferrum://browsers` and `ferrum://bot-profiles` to see available configurations
3. **Handle sessions properly**: Close sessions when done to free resources
4. **Snapshot before acting**: call `snapshot` and use the returned refs (`ref:e12`) instead of guessing selectors
5. **Wait explicitly**: use `wait_for_selector` / `wait_for_text` / `wait_for_network_idle` rather than fixed delays
6. **Use appropriate selectors**: Prefer CSS selectors for performance, XPath for complex queries
7. **Set timeouts wisely**: Increase timeout for slow-loading pages
8. **Force clicks sparingly**: Only use `force: true` when necessary, as it bypasses visibility checks
9. **Screenshot optimization**: Use `jpeg` format for smaller file sizes when quality is not critical

