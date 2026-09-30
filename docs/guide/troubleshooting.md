# Troubleshooting

Start by reading the logs. They go to `LOG_FILE`: `./logs/ferrum_mcp.log` relative to the directory the server was started from, or `stderr`. Set `LOG_LEVEL=debug` for details. With Claude Desktop, set an absolute `LOG_FILE` in the config's `env` block (see [Getting started](/guide/getting-started#claude-desktop)).

## Server won't start

| Message / symptom | Cause and fix |
|---|---|
| `ERROR: Invalid browser configuration` | A configured browser path (`BROWSER_PATH`, `BROWSER_<ID>`, `BOTBROWSER_PATH`) doesn't exist. Fix or remove it; without one, Ferrum finds the system Chrome/Chromium. |
| `Failed to start browser: …` | Chrome can't launch: check it is installed (`which google-chrome chromium chromium-browser`), and on a server without display set `BROWSER_HEADLESS=true`. In Docker, add `--security-opt seccomp=unconfined`. |
| Port already in use | `lsof -i :3000`, or start with `--port 3001` / `MCP_SERVER_PORT=3001`. |
| Code loading errors after an update | `bundle install`, then `RACK_ENV=production bundle exec ruby -r ./lib/ferrum_mcp -e 'puts :ok'` (eager-loads every file, as CI does). |

`ferrum-mcp help` lists the CLI options (`start`, `--transport`, `--host`, `--port`, `--log-level`).

## MCP client doesn't see the server

- **Claude Desktop**: validate the JSON (`python3 -m json.tool claude_desktop_config.json`), use absolute paths if `ferrum-mcp` isn't on the PATH Claude Desktop sees (rbenv, asdf), restart Claude Desktop, then check its MCP log (macOS: `~/Library/Logs/Claude/mcp*.log`).
- **Test the server by hand** with the MCP Inspector: `npx @modelcontextprotocol/inspector ferrum-mcp start --transport stdio`. It performs the `initialize` handshake, then lets you call `tools/list` and any tool.
- **HTTP transport**: the endpoint is `http://localhost:3000/mcp` (not `0.0.0.0`, not `/mcp/v1`). `curl http://localhost:3000/health` should return `{"status":"ok"}`.
- **`Unauthorized`**: `API_KEY_ENABLED=true` requires `Authorization: Bearer <key>` on `/mcp`.
- **`Rate limit exceeded`**: raise `RATE_LIMIT_MAX_REQUESTS` / `RATE_LIMIT_WINDOW`, or set `RATE_LIMIT_ENABLED=false` for local use.

## Sessions

| Message / symptom | Cause and fix |
|---|---|
| `session_id is required` | Every browser tool needs one: call `create_session` first. |
| `Session not found: <id>` | The session was closed, timed out (30 min idle) or belongs to another server instance. `list_sessions` returns `{ count, sessions: [{ id, … }] }`. |
| `Maximum concurrent sessions limit reached (10)` | Close sessions you no longer use, or raise `MAX_CONCURRENT_SESSIONS`. |
| `Browser for session … died during a tool call` | Chrome crashed. Retry the call: the session restarts Chrome (the page state is lost). |
| `headless: false` rejected | Expected in Docker (`DOCKER=true`); use the gem locally to watch the browser. |

## Tools

| Symptom | Fix |
|---|---|
| `Element not found: <selector>` | Take a `snapshot` and use its refs (`ref:e12`), or wait first with `wait_for_selector` (states visible / hidden / attached / detached) or `wait_for_text`. Selectors can be CSS, XPath (`//…` or `xpath:…`) or refs. |
| `Failed to click: … Try with force: true` | Something covers the element (banner, modal): `accept_cookies`, close the overlay, or retry with `force: true`. `click` and `fill_form` already retry moving elements. |
| Navigation times out | `navigate` waits for the network to go idle; pages that never go idle need `wait_for_idle: false`, then `wait_for_selector`. `timeout` defaults to 30 s. |
| `Navigation to <host> is not allowed by the server URL policy` | The host is blocked by `ALLOWED_HOSTS` / `BLOCKED_HOSTS`. |
| `fill_form` ignores fields | `fields` is an array: `[{ "selector": "#user", "value": "demo" }, { "selector": "#pass", "value": "secret", "clear": true }]`. |
| `evaluate_js` / `execute_script` errors | `evaluate_js` takes `expression` and returns its JSON-serializable value; `execute_script` runs statements without a return value. |
| `upload_file` refuses a file | Only paths under `UPLOAD_ALLOWED_DIRS` (default: working directory and temp dir) can be uploaded. |

## CAPTCHAs

`solve_captcha` fails with `CAPTCHA not solved (<type>, <status>): <reason>`:

| Status | Meaning and what to do |
|---|---|
| `distrusted` | reCAPTCHA only served its decoy audio to this session. It stopped early to protect the IP. A long-lived browser profile (`user_profile_id`) and a residential IP help; retrying from the same session and IP won't. |
| `blocked` | Google answered "Try again later" for this IP. Wait, or change IP. |
| `challenge_required` | hCaptcha asked for a visual challenge (no audio exists); a screenshot is attached. |
| `failed` | The widget never reached a solved state (Turnstile rejected the click, no challenge appeared, attempts exhausted). |

- `No supported CAPTCHA found on the page`: no reCAPTCHA, hCaptcha or Turnstile frame loaded. A full-page "Sorry, you have been blocked" is a Cloudflare firewall block of the IP, not a challenge.
- `whisper-cli not found`: install whisper.cpp (`brew install whisper-cpp`) or set `WHISPER_PATH`. Only reCAPTCHA needs it. `ffmpeg` is recommended for decoding.
- `Failed to download Whisper model`: models go to `~/.whisper.cpp/models/`, which must be writable. You can also download `ggml-<model>.bin` by hand, or point `WHISPER_MODEL` at a `.bin` file.
- `CAPTCHA_AUDIO_DIR=/some/dir` keeps every reCAPTCHA audio and its transcription, to inspect what was heard.

## BotBrowser

- A profile only applies when the session passes `bot_profile_id` (the lowercase `<ID>` of `BOT_PROFILE_<ID>`). A profile whose file doesn't exist is silently skipped; check the path, or the mount in Docker.
- `browser_id: "botbrowser"` only exists if `BROWSER_BOTBROWSER` is defined; `BOTBROWSER_PATH` alone creates the browser `default`.
- Demo profiles make sessions unstable; use trial or paid profiles.

More in [BotBrowser in Docker](/deployment/botbrowser-docker) and [Configuration](/guide/configuration).

## Docker

See the [common issues table in the Docker guide](/deployment/docker#common-issues): `seccomp=unconfined`, `LOG_FILE=stderr` for `docker logs`, mounted `logs/` owned by UID 1000, headless only.

## Still stuck

Open an issue at https://github.com/Eth3rnit3/FerrumMCP/issues with the FerrumMCP version (`ferrum-mcp version`), how you run it (gem, Docker, source), the tool call, and the relevant log lines with `LOG_LEVEL=debug`.
