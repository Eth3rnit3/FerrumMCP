# Interaction

## click

Click on an element using a CSS selector or XPath.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector, XPath (`xpath:` prefix) or snapshot ref (`ref:e12`) |
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

## fill_form

Fill one or more form fields with values.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| fields | array | Yes | Array of field objects with `selector` and `value` |
| session_id | string | Yes | Session ID to use |

**Field Object:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | CSS selector, XPath or snapshot ref of the field |
| value | string | Yes | Value to type |
| clear | boolean | No | Clear the field before typing (default: false) |

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

## press_key

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

## hover

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

## drag_and_drop

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

## scroll

Scroll the page or a scrollable element, or bring an element into view.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | No | Element to scroll into view, or the scrollable container when `direction` is given |
| direction | string | No | `up`, `down`, `left`, `right`, `top`, `bottom` |
| amount | number | No | Pixels for up/down/left/right (default: 500) |
| x | number | No | Absolute horizontal scroll position |
| y | number | No | Absolute vertical scroll position |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{ "name": "scroll", "arguments": { "direction": "down", "amount": 800, "session_id": "uuid-1234" } }
```

**Example Response:**

```json
{ "x": 0, "y": 800, "target": "window" }
```

**Notes:**
- `selector` alone scrolls that element into the middle of the viewport
- `selector` + `direction` scrolls inside that container (infinite lists, modals)

## select_option

Select option(s) in a `<select>` element and fire `input`/`change` events.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | Selector of the `<select>` |
| value | string | No | Option value |
| label | string | No | Option visible text |
| index | integer | No | Zero-based option index |
| values | array | No | Several option values (multiple selects) |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{ "name": "select_option", "arguments": { "selector": "#plan", "label": "Pro plan", "session_id": "uuid-1234" } }
```

**Example Response:**

```json
{ "selector": "#plan", "selected": [{ "value": "pro", "label": "Pro plan" }] }
```

## upload_file

Attach files from the **server's** filesystem to an `<input type="file">`.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| selector | string | Yes | Selector of the file input |
| paths | array | Yes | Absolute paths of the files |
| session_id | string | Yes | Session ID to use |

**Example Request:**

```json
{ "name": "upload_file", "arguments": { "selector": "#avatar", "paths": ["/tmp/avatar.png"], "session_id": "uuid-1234" } }
```

**Notes:**
- Files must live under one of `UPLOAD_ALLOWED_DIRS` (default: current directory and the temp dir); symlinks are resolved
- Missing files are rejected before touching the browser

## accept_cookies

Detect a cookie consent banner and accept all cookies. The tool only clicks an accept button that sits inside a consent banner, never a refusal disguised as a way out ("Continuer sans accepter", "Accept only necessary"). After the click it checks that the banner closed.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| wait | number | No | Seconds to wait for the banner to appear; returns as soon as it is accepted (default: 3) |
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
  "message": "Cookie consent accepted",
  "strategy": "known_cmp",
  "clicked": "Tout accepter"
}
```

| Field | Description |
|-------|-------------|
| `strategy` | `known_cmp` (a known platform's accept button), `text` (an accept wording inside a consent banner) or `cmp_api` (the platform's JavaScript API) |
| `clicked` | Label of the button that was clicked |
| `frame` | URL of the iframe holding the banner, when it is not the page itself |
| `cmp` | Platform answered through its API (`Didomi`, `OneTrust`, `Cookiebot`, `Usercentrics`, `tarteaucitron`) |

**How the button is chosen:**
1. The page, its open shadow roots and its iframes are scanned for buttons, links, `<input type="submit">` and `role="button"` elements. Labels come from the text, the `value` or the `aria-label`.
2. Labels that refuse or give partial consent are discarded ("refuser", "continuer sans accepter", "only necessary", "ablehnen", ...). Settings entries ("personnaliser", "manage options") are discarded as well, unless the label is an accept-all wording such as "Accepter tous les paramètres".
3. Of the remaining buttons, known accept buttons (OneTrust, Cookiebot, Didomi, Sourcepoint, Quantcast, Google, Amazon, ...) come first, then "accept all" wordings, then plain "accept" and finally "OK". English, French, German, Spanish, Italian, Portuguese and Dutch are recognised.
4. A generic wording only counts inside a consent banner, identified by its id, class or label, or by nearby text mentioning cookies. An "I agree" button on a signup form is left alone.
5. If the banner is still visible after a real click, the tool tries a DOM click. If a known platform is still waiting for an answer, it calls the platform's "accept all" API. Otherwise the tool reports that the banner is still visible instead of claiming success.

## solve_captcha

Detect the CAPTCHA on the current page and solve it. Detection relies on the widgets' own frames, so the tool never clicks or types into the site's forms. Success is only reported once the provider confirms it.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| session_id | string | Yes | Session ID to use |
| type | string | No | `auto` (default), `recaptcha`, `hcaptcha` or `turnstile` |
| max_attempts | integer | No | Maximum challenges to answer (default: 5) |
| language | string | No | Expected audio language for Whisper, e.g. `en` or `auto` (default: `WHISPER_LANGUAGE` or `en`) |
| screenshot_on_failure | boolean | No | Attach a screenshot of the page when the CAPTCHA is not solved (default: true) |

Solving can take a minute or more (human-like warm-up, audio rounds): the tool sends MCP progress notifications
(`notifications/progress`) when the client provides a progress token.

**Example Response (solved):**

```json
{
  "solved": true,
  "type": "turnstile",
  "status": "solved",
  "attempts": 1,
  "message": "Turnstile solved",
  "token": "0.Abc…",
  "token_length": 812
}
```

**When it cannot solve**, the tool returns an error with an explicit status and a screenshot of the page
(unless `screenshot_on_failure: false`), so the agent can see the challenge grid, the block page or the error banner:

| Status | Meaning |
|--------|---------|
| `blocked` | The provider refuses to serve challenges: reCAPTCHA's "Try again later", Cloudflare's "Sorry, you have been blocked" page |
| `distrusted` | reCAPTCHA only serves its decoy audio to this session; the tool stops after the first one (recognised by fingerprint) to protect the IP |
| `challenge_required` | A visual challenge appeared (hCaptcha) |
| `failed` | Attempts exhausted or the widget never reached a solved state |

**Supported CAPTCHAs:**
- **Cloudflare Turnstile** (widget, invisible and managed modes) and the "Just a moment…" interstitial: human-like click on the widget when there is one, headful and headless
- **reCAPTCHA v2** (checkbox, invisible, enterprise): audio challenge transcribed locally with whisper.cpp; decoy audio is detected and never answered. The token is read from the response textarea or, for callback-only integrations, through `grecaptcha.getResponse()`
- **hCaptcha**: checkbox only (hCaptcha no longer offers an audio challenge)

**Notes:**
- reCAPTCHA requires `whisper-cli` and `ffmpeg`; see [Whisper configuration](/guide/configuration#whisper-configuration-captcha-solving)
- Anonymous sessions on shared or datacenter IPs usually get `distrusted` from reCAPTCHA; a long-lived browser profile and a residential IP help

