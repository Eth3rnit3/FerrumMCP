# Docker

## Images

Published on Docker Hub as `eth3rnit3/ferrum-mcp`, multi-arch (`linux/amd64`, `linux/arm64`).

| Tag | Base | Browser |
|---|---|---|
| `latest`, `1.1.0`, `1.1`, `1` | `ruby:3.3-alpine` | Chromium |
| `botbrowser`, `1.1.0-botbrowser`, `1.1-botbrowser` | `ruby:3.3-slim` | [BotBrowser](/deployment/botbrowser-docker) only (no Chromium) |

Both run as the non-root user `ferrum` (UID 1000), work in `/app`, expose port 3000, have a `HEALTHCHECK` on `/health`, and start the HTTP server (`bin/ferrum-mcp start`).

## Run

```bash
# HTTP server: MCP endpoint http://localhost:3000/mcp, health check /health
docker run -d --name ferrum-mcp --security-opt seccomp=unconfined -p 3000:3000 \
  -e LOG_FILE=stderr eth3rnit3/ferrum-mcp:latest

# STDIO, for MCP clients that spawn the server themselves
docker run --rm -i --security-opt seccomp=unconfined -e LOG_FILE=stderr \
  eth3rnit3/ferrum-mcp:latest bin/ferrum-mcp start --transport stdio
```

- `--security-opt seccomp=unconfined` is what CI uses for Chrome in the container.
- Logs go to `/app/logs/ferrum_mcp.log` by default; `-e LOG_FILE=stderr` makes them visible with `docker logs`.
- **Sessions are always headless**: `create_session` rejects `headless: false` when `DOCKER=true`.
- The sandbox and `/dev/shm` flags (`--no-sandbox`, `--disable-dev-shm-usage`) are added automatically in the container.

### Connect a client

```bash
# Claude Code, against the running container
claude mcp add --transport http ferrum http://localhost:3000/mcp
```

Claude Desktop (`claude_desktop_config.json`), spawning a container per conversation:

```json
{
  "mcpServers": {
    "ferrum": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "--security-opt", "seccomp=unconfined", "-e", "LOG_FILE=stderr",
               "eth3rnit3/ferrum-mcp:latest", "bin/ferrum-mcp", "start", "--transport", "stdio"]
    }
  }
}
```

## Configuration

Pass any variable from the [configuration guide](/guide/configuration) with `-e`. Set by the images:

| Variable | Value |
|---|---|
| `DOCKER` | `true` (forces headless, adds the container Chrome flags) |
| `BROWSER_PATH` / `BOTBROWSER_PATH` | `/usr/bin/chromium-browser` (standard) / `/opt/botbrowser/chrome` (botbrowser) |
| `BROWSER_HEADLESS` | `true` |
| `BROWSER_TIMEOUT` | `120` |
| `LOG_LEVEL` | `info` |

The listening address comes from `MCP_SERVER_HOST` (default `0.0.0.0`) and `MCP_SERVER_PORT` (default `3000`).

Before exposing a container beyond localhost:

```bash
-e API_KEY_ENABLED=true -e API_KEY=$(openssl rand -hex 32)   # clients send Authorization: Bearer <key>
-e BLOCKED_HOSTS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16   # keep the browser off your network
```

Rate limiting is on by default (`RATE_LIMIT_MAX_REQUESTS=100` per `RATE_LIMIT_WINDOW=60` seconds). Set `TRUST_PROXY=true` only behind a reverse proxy.

`/mcp` only accepts loopback `Host` headers by default (DNS rebinding protection). Reaching the container through
`localhost:3000` on the host works as is; from another container or machine, set `MCP_ALLOWED_HOSTS` to the name
or IP the clients use (e.g. `-e MCP_ALLOWED_HOSTS=ferrum-mcp` on a Compose network).

## CAPTCHAs in Docker

`solve_captcha` handles Cloudflare Turnstile and the hCaptcha checkbox in both images. reCAPTCHA's audio challenge needs `whisper-cli` (whisper.cpp), which neither image ships: build your own image on top if you need it.

## Docker Compose

```yaml
services:
  ferrum-mcp:
    image: eth3rnit3/ferrum-mcp:latest
    ports:
      - "127.0.0.1:3000:3000"
    security_opt:
      - seccomp=unconfined
    environment:
      LOG_FILE: stderr
      API_KEY_ENABLED: "true"
      API_KEY: ${FERRUM_API_KEY}
      # Clients on the Compose network reach the service by name: allow that Host header
      # MCP_ALLOWED_HOSTS: ferrum-mcp
    restart: unless-stopped
```

```bash
docker compose up -d
docker compose logs -f
```

To keep logs in a file instead, mount a directory writable by UID 1000: `mkdir logs && sudo chown 1000:1000 logs`, then `-v "$PWD/logs:/app/logs"`.

## Build locally

```bash
docker build -t ferrum-mcp .                                                      # standard image
docker build -f Dockerfile.with-botbrowser -t ferrum-mcp:botbrowser .             # BotBrowser image
docker build -f Dockerfile.with-botbrowser --build-arg BOTBROWSER_VERSION=<tag> -t ferrum-mcp:botbrowser .
```

## Common issues

| Symptom | Fix |
|---|---|
| Chrome fails to start / crashes | Add `--security-opt seccomp=unconfined` |
| `docker logs` is empty | Add `-e LOG_FILE=stderr` |
| Container exits right away with a mounted `logs/` | The host directory must be writable by UID 1000 |
| `/mcp` answers `403 Forbidden: Invalid Host header` | Clients reach the container through a name or IP other than `localhost`: set `MCP_ALLOWED_HOSTS` to it |
| `headless: false` rejected | Expected in Docker; use the gem locally to watch the browser |
| `Unable to find image 'ferrum-mcp:latest'` | That tag only exists after a local build; use `eth3rnit3/ferrum-mcp:latest` |

More in [Troubleshooting](/guide/troubleshooting).
