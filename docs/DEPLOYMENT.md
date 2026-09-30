# Deployment

FerrumMCP holds browser sessions **in memory**: run a single instance per set of clients (or pin clients to an instance), and give it enough RAM for Chrome (~300-500 MB per open session, `MAX_CONCURRENT_SESSIONS` defaults to 10).

## Security checklist

A browser server reachable by others can browse your internal network and read files. Before exposing it:

| Setting | Why |
|---|---|
| `API_KEY_ENABLED=true`, `API_KEY` (or `API_KEYS=k1,k2` for rotation) | Clients must send `Authorization: Bearer <key>` on `/mcp`; `/health` and `/` stay open |
| `BLOCKED_HOSTS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost` | Keeps the browser off private ranges and cloud metadata. Or allow-list with `ALLOWED_HOSTS` (exact host, `*.suffix`, CIDR) |
| `UPLOAD_ALLOWED_DIRS=/srv/uploads` | Limits which local files `upload_file` can read (default: working directory and temp dir) |
| `RATE_LIMIT_MAX_REQUESTS` / `RATE_LIMIT_WINDOW` | Per-client limit, on by default (100 requests / 60 s) |
| `TRUST_PROXY=true` | Only behind a reverse proxy you control, so rate limiting uses `X-Forwarded-For` |
| `MCP_ALLOWED_HOSTS=ferrum.example.com` | `/mcp` only accepts loopback `Host` headers by default (DNS rebinding protection); list the names or IPs clients use |
| TLS | Terminate it in a reverse proxy (below) |

Generate a key with `openssl rand -hex 32` or `rake generate_api_key`.

## Docker

The simplest option; see [Docker](DOCKER.md) for images, Compose and the container specifics. A locked-down run:

```bash
docker run -d --name ferrum-mcp --restart unless-stopped \
  --security-opt seccomp=unconfined \
  --read-only --tmpfs /tmp --tmpfs /home/ferrum --tmpfs /app/logs --tmpfs /app/tmp \
  --memory 4g --cpus 2 \
  -p 127.0.0.1:3000:3000 \
  -e LOG_FILE=stderr \
  -e API_KEY_ENABLED=true -e API_KEY="$FERRUM_API_KEY" \
  -e BLOCKED_HOSTS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16 \
  eth3rnit3/ferrum-mcp:latest
```

## systemd (gem)

```bash
sudo useradd --system --create-home --home-dir /opt/ferrum-mcp ferrum
sudo gem install ferrum-mcp            # or install it for a Ruby the ferrum user can run
```

`/etc/systemd/system/ferrum-mcp.service`:

```ini
[Unit]
Description=FerrumMCP browser automation server
After=network.target

[Service]
User=ferrum
WorkingDirectory=/opt/ferrum-mcp
Environment=BROWSER_HEADLESS=true
Environment=LOG_FILE=stderr
EnvironmentFile=-/opt/ferrum-mcp/.env
ExecStart=/usr/local/bin/ferrum-mcp start --transport http --host 127.0.0.1 --port 3000
Restart=on-failure
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/ferrum-mcp

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now ferrum-mcp
journalctl -u ferrum-mcp -f
```

- Servers have no display: keep `BROWSER_HEADLESS=true` (the `.env.example` default is `false`).
- `ReadWritePaths=/opt/ferrum-mcp` also covers the Whisper models (`~/.whisper.cpp/models`), downloaded on first reCAPTCHA solve.
- Adjust `ExecStart` to `which ferrum-mcp` if Ruby is not the system one.

## Reverse proxy (nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name ferrum.example.com;
    ssl_certificate     /etc/letsencrypt/live/ferrum.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ferrum.example.com/privkey.pem;

    location /health { proxy_pass http://127.0.0.1:3000; access_log off; }

    location /mcp {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;              # streamable HTTP / SSE
        proxy_request_buffering off;
        proxy_read_timeout 1h;            # long-lived SSE stream
    }

    location / { return 404; }
}
```

Set `TRUST_PROXY=true` and `MCP_ALLOWED_HOSTS=ferrum.example.com` on FerrumMCP when it sits behind this proxy
(the proxy forwards the public `Host`, which the DNS rebinding protection would otherwise reject).

## Kubernetes

Run **one replica**, or several with client affinity: sessions and MCP HTTP sessions live in each pod's memory, and a `session_id` sent to another pod fails with "Session not found".

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: ferrum-mcp }
spec:
  replicas: 1
  selector: { matchLabels: { app: ferrum-mcp } }
  template:
    metadata: { labels: { app: ferrum-mcp } }
    spec:
      containers:
        - name: ferrum-mcp
          image: eth3rnit3/ferrum-mcp:latest
          ports: [{ containerPort: 3000 }]
          env:
            - { name: LOG_FILE, value: stderr }
            - { name: API_KEY_ENABLED, value: "true" }
            - name: API_KEY
              valueFrom: { secretKeyRef: { name: ferrum-mcp, key: api-key } }
          securityContext:
            seccompProfile: { type: Unconfined }
          resources:
            requests: { memory: 1Gi, cpu: 500m }
            limits: { memory: 4Gi, cpu: "2" }
          readinessProbe: { httpGet: { path: /health, port: 3000 } }
          livenessProbe: { httpGet: { path: /health, port: 3000 }, periodSeconds: 30 }
---
apiVersion: v1
kind: Service
metadata: { name: ferrum-mcp }
spec:
  selector: { app: ferrum-mcp }
  sessionAffinity: ClientIP
  ports: [{ port: 3000, targetPort: 3000 }]
```

## Monitoring

- `GET /health` returns `{"status":"ok"}`; `GET /` returns the server name, version and endpoints.
- Logs: `LOG_FILE` (a path, or `stderr` for Docker/systemd/Kubernetes), level with `LOG_LEVEL` (`debug`, `info`, `warn`, `error`).
- Idle sessions close after 30 minutes; a dead Chrome is restarted on the next call.
