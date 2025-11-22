# Production Deployment Guide

This guide covers deploying FerrumMCP in production environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Options](#deployment-options)
- [Docker Deployment](#docker-deployment)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Systemd Service](#systemd-service)
- [Reverse Proxy Setup](#reverse-proxy-setup)
- [Security Hardening](#security-hardening)
- [Monitoring](#monitoring)
- [Performance Tuning](#performance-tuning)
- [Backup and Recovery](#backup-and-recovery)

---

## Prerequisites

### System Requirements

**Minimum**:
- CPU: 2 cores
- RAM: 2 GB
- Disk: 5 GB
- OS: Linux (Ubuntu 20.04+, Debian 11+, CentOS 8+)

**Recommended**:
- CPU: 4+ cores
- RAM: 4+ GB (add 500MB per concurrent session)
- Disk: 10+ GB SSD
- OS: Ubuntu 22.04 LTS

### Software Requirements

- Ruby 3.2 or higher
- Chrome/Chromium browser
- (Optional) BotBrowser for anti-detection
- (Optional) whisper-cli for CAPTCHA solving
- (Optional) nginx or Apache for reverse proxy

### Network Requirements

- **Inbound**: Port 3000 (HTTP) or custom port
- **Outbound**: Port 443 (HTTPS) for browsing
- **Internal**: PostgreSQL, Redis (if adding persistence)

---

## Deployment Options

### Option 1: Docker (Recommended)

**Pros**:
- ✅ Isolated environment
- ✅ Easy to update
- ✅ Consistent across platforms
- ✅ Built-in Chrome

**Cons**:
- ❌ Slight overhead
- ❌ Requires Docker knowledge

**Best for**: Most production deployments

### Option 2: Systemd Service

**Pros**:
- ✅ Native performance
- ✅ System integration
- ✅ Easy log management

**Cons**:
- ❌ Manual dependency management
- ❌ Platform-specific setup

**Best for**: Dedicated servers

### Option 3: Kubernetes

**Pros**:
- ✅ Auto-scaling
- ✅ High availability
- ✅ Rolling updates

**Cons**:
- ❌ Complex setup
- ❌ Requires K8s cluster

**Best for**: Large-scale deployments

---

## Docker Deployment

### Basic Docker Deployment

1. **Pull the image**:
   ```bash
   docker pull eth3rnit3/ferrum-mcp:latest
   ```

2. **Create environment file**:
   ```bash
   cat > .env << EOF
   MCP_SERVER_HOST=0.0.0.0
   MCP_SERVER_PORT=3000
   BROWSER_HEADLESS=true
   LOG_LEVEL=info
   MAX_CONCURRENT_SESSIONS=10
   EOF
   ```

3. **Run container**:
   ```bash
   docker run -d \
     --name ferrum-mcp \
     --env-file .env \
     --shm-size=2g \
     -p 3000:3000 \
     --restart unless-stopped \
     eth3rnit3/ferrum-mcp:latest
   ```

4. **Verify deployment**:
   ```bash
   curl http://localhost:3000/health
   ```

### Docker Compose Deployment

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  ferrum-mcp:
    image: eth3rnit3/ferrum-mcp:latest
    container_name: ferrum-mcp
    restart: unless-stopped
    shm_size: 2g
    ports:
      - "3000:3000"
    environment:
      - MCP_SERVER_HOST=0.0.0.0
      - MCP_SERVER_PORT=3000
      - BROWSER_HEADLESS=true
      - LOG_LEVEL=info
      - MAX_CONCURRENT_SESSIONS=10
      - MAX_REQUESTS_PER_MINUTE=100
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config  # For BotBrowser profiles
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

Deploy:
```bash
docker-compose up -d
```

### Multi-Container Setup with Nginx

`docker-compose.yml`:

```yaml
version: '3.8'

services:
  ferrum-mcp:
    image: eth3rnit3/ferrum-mcp:latest
    container_name: ferrum-mcp
    restart: unless-stopped
    shm_size: 2g
    environment:
      - MCP_SERVER_HOST=0.0.0.0
      - MCP_SERVER_PORT=3000
      - BROWSER_HEADLESS=true
      - LOG_LEVEL=info
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - ferrum-net

  nginx:
    image: nginx:alpine
    container_name: ferrum-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - ferrum-mcp
    networks:
      - ferrum-net

networks:
  ferrum-net:
    driver: bridge
```

---

## Kubernetes Deployment

### Deployment Manifest

`k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ferrum-mcp
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ferrum-mcp
  template:
    metadata:
      labels:
        app: ferrum-mcp
    spec:
      containers:
      - name: ferrum-mcp
        image: eth3rnit3/ferrum-mcp:latest
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: MCP_SERVER_HOST
          value: "0.0.0.0"
        - name: MCP_SERVER_PORT
          value: "3000"
        - name: BROWSER_HEADLESS
          value: "true"
        - name: LOG_LEVEL
          value: "info"
        - name: MAX_CONCURRENT_SESSIONS
          valueFrom:
            configMapKeyRef:
              name: ferrum-config
              key: max_sessions
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        volumeMounts:
        - name: shm
          mountPath: /dev/shm
        - name: logs
          mountPath: /app/logs
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 2Gi
      - name: logs
        emptyDir: {}
```

### Service Manifest

`k8s/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ferrum-mcp
  namespace: default
spec:
  selector:
    app: ferrum-mcp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer
```

### ConfigMap

`k8s/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ferrum-config
  namespace: default
data:
  max_sessions: "10"
  max_requests_per_minute: "100"
```

### Deploy to Kubernetes

```bash
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check status
kubectl get pods -l app=ferrum-mcp
kubectl get svc ferrum-mcp
```

---

## Systemd Service

### Service File

Create `/etc/systemd/system/ferrum-mcp.service`:

```ini
[Unit]
Description=FerrumMCP Browser Automation Server
After=network.target

[Service]
Type=simple
User=ferrum
Group=ferrum
WorkingDirectory=/opt/ferrum-mcp
Environment="PATH=/home/ferrum/.rbenv/shims:/home/ferrum/.rbenv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/opt/ferrum-mcp/.env
ExecStart=/home/ferrum/.rbenv/shims/ruby /opt/ferrum-mcp/bin/ferrum-mcp --transport http
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ferrum-mcp

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/ferrum-mcp/logs

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
```

### Setup Steps

1. **Create user**:
   ```bash
   sudo useradd -r -s /bin/bash -d /opt/ferrum-mcp ferrum
   ```

2. **Install FerrumMCP**:
   ```bash
   sudo mkdir -p /opt/ferrum-mcp
   sudo chown ferrum:ferrum /opt/ferrum-mcp

   # As ferrum user
   sudo -u ferrum -i
   cd /opt/ferrum-mcp
   git clone https://github.com/Eth3rnit3/FerrumMCP.git .
   bundle install --deployment --without development test
   ```

3. **Configure environment**:
   ```bash
   sudo -u ferrum cp /opt/ferrum-mcp/.env.example /opt/ferrum-mcp/.env
   sudo -u ferrum nano /opt/ferrum-mcp/.env
   ```

4. **Enable and start service**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable ferrum-mcp
   sudo systemctl start ferrum-mcp
   ```

5. **Check status**:
   ```bash
   sudo systemctl status ferrum-mcp
   sudo journalctl -u ferrum-mcp -f
   ```

---

## Reverse Proxy Setup

### Nginx Configuration

`/etc/nginx/sites-available/ferrum-mcp`:

```nginx
upstream ferrum_backend {
    server 127.0.0.1:3000 fail_timeout=0;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=ferrum_limit:10m rate=10r/s;

server {
    listen 80;
    server_name ferrum.example.com;

    # Redirect to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ferrum.example.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/ferrum.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ferrum.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/ferrum_access.log;
    error_log /var/log/nginx/ferrum_error.log;

    # Health check (no rate limit)
    location /health {
        proxy_pass http://ferrum_backend;
        access_log off;
    }

    # MCP endpoint
    location /mcp {
        # Rate limiting
        limit_req zone=ferrum_limit burst=20 nodelay;

        # Proxy settings
        proxy_pass http://ferrum_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;

        # Buffering
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Block all other paths
    location / {
        return 404;
    }
}
```

Enable and reload:
```bash
sudo ln -s /etc/nginx/sites-available/ferrum-mcp /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Apache Configuration

`/etc/apache2/sites-available/ferrum-mcp.conf`:

```apache
<VirtualHost *:80>
    ServerName ferrum.example.com
    Redirect permanent / https://ferrum.example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName ferrum.example.com

    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/ferrum.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/ferrum.example.com/privkey.pem

    # Security Headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options "DENY"
    Header always set X-Content-Type-Options "nosniff"

    # Logging
    ErrorLog ${APACHE_LOG_DIR}/ferrum_error.log
    CustomLog ${APACHE_LOG_DIR}/ferrum_access.log combined

    # Proxy
    ProxyRequests Off
    ProxyPreserveHost On

    <Location /mcp>
        ProxyPass http://localhost:3000/mcp
        ProxyPassReverse http://localhost:3000/mcp
        ProxyTimeout 120
    </Location>

    <Location /health>
        ProxyPass http://localhost:3000/health
        ProxyPassReverse http://localhost:3000/health
    </Location>
</VirtualHost>
```

Enable and reload:
```bash
sudo a2enmod ssl proxy proxy_http headers
sudo a2ensite ferrum-mcp
sudo apachectl configtest
sudo systemctl reload apache2
```

---

## Security Hardening

### 1. Network Security

**Firewall (UFW)**:
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw enable
```

**Firewall (iptables)**:
```bash
# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow localhost
iptables -A INPUT -i lo -j ACCEPT

# Drop everything else
iptables -P INPUT DROP
iptables -P FORWARD DROP
```

### 2. Application Security

**Environment Variables**:
```bash
# Use strong configurations
MAX_CONCURRENT_SESSIONS=10
SESSION_IDLE_TIMEOUT=1800
MAX_REQUESTS_PER_MINUTE=100

# Bind to localhost if using reverse proxy
MCP_SERVER_HOST=127.0.0.1
```

**File Permissions**:
```bash
# Restrict .env file
chmod 600 .env
chown ferrum:ferrum .env

# Logs directory
chmod 750 logs/
chown -R ferrum:ferrum logs/
```

### 3. Docker Security

```bash
docker run -d \
  --name ferrum-mcp \
  --user 1000:1000 \               # Non-root user
  --read-only \                     # Read-only filesystem
  --tmpfs /tmp:rw,noexec,nosuid \  # Writable tmp
  --security-opt no-new-privileges \ # No privilege escalation
  --cap-drop ALL \                  # Drop all capabilities
  --cap-add NET_BIND_SERVICE \     # Only needed capabilities
  --env-file .env \
  -p 127.0.0.1:3000:3000 \         # Bind to localhost only
  eth3rnit3/ferrum-mcp:latest
```

### 4. SSL/TLS

**Let's Encrypt**:
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d ferrum.example.com
sudo systemctl reload nginx
```

**Auto-renewal**:
```bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

---

## Monitoring

### Health Checks

```bash
# Basic health check
curl http://localhost:3000/health

# Response
{
  "status": "ok",
  "version": "1.0.0",
  "active_sessions": 3,
  "uptime": 3600
}
```

### Logging

**Structured logging** (planned v1.1):
```bash
# Current: Plain text
tail -f logs/ferrum_mcp.log

# Future: JSON logs
tail -f logs/ferrum_mcp.log | jq .
```

### Metrics (Prometheus)

**Planned for v1.2**:
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'ferrum-mcp'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'
```

### Alerting

**Example Grafana alerts**:
- Active sessions > 8
- Memory usage > 80%
- Error rate > 1%
- Response time > 5s

---

## Performance Tuning

### System Tuning

**Increase file descriptors**:
```bash
# /etc/security/limits.conf
ferrum soft nofile 65536
ferrum hard nofile 65536
```

**Shared memory**:
```bash
# For Docker
--shm-size=2g

# For systemd
# Add tmpfs mount in service file
```

### Application Tuning

**Session limits**:
```bash
# Conservative (low-resource server)
MAX_CONCURRENT_SESSIONS=5

# Moderate (4GB RAM)
MAX_CONCURRENT_SESSIONS=10

# Aggressive (8GB+ RAM)
MAX_CONCURRENT_SESSIONS=20
```

**Browser options**:
```ruby
# Faster but less stable
create_session(
  headless: true,
  browser_options: {
    '--disable-dev-shm-usage': nil,
    '--disable-gpu': nil,
    '--no-sandbox': nil,
    '--disable-setuid-sandbox': nil
  }
)
```

### Resource Estimates

| Sessions | CPU | RAM | Notes |
|----------|-----|-----|-------|
| 1-3 | 1 core | 2 GB | Light usage |
| 4-10 | 2 cores | 4 GB | Moderate usage |
| 11-20 | 4 cores | 8 GB | Heavy usage |
| 21+ | 8 cores | 16 GB | Enterprise |

---

## Backup and Recovery

### What to Backup

- **Configuration**: `.env`, browser configs
- **Logs**: `logs/` directory (optional)
- **BotBrowser Profiles**: `config/` directory

### Backup Script

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/ferrum-mcp"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration
tar -czf $BACKUP_DIR/config_$DATE.tar.gz \
  .env \
  config/

# Backup logs (last 7 days)
find logs/ -name "*.log" -mtime -7 | \
  tar -czf $BACKUP_DIR/logs_$DATE.tar.gz -T -

# Keep last 30 days of backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR"
```

### Recovery

```bash
# Restore configuration
cd /opt/ferrum-mcp
tar -xzf /backups/ferrum-mcp/config_20241122_120000.tar.gz

# Restart service
sudo systemctl restart ferrum-mcp
```

---

## Checklist for Production

- [ ] Ruby 3.2+ installed
- [ ] Chrome/Chromium installed
- [ ] FerrumMCP deployed (Docker/systemd/K8s)
- [ ] Environment variables configured
- [ ] Session limits set (`MAX_CONCURRENT_SESSIONS`)
- [ ] Rate limiting configured
- [ ] Reverse proxy setup (nginx/Apache)
- [ ] SSL/TLS certificates configured
- [ ] Firewall rules applied
- [ ] Health checks working
- [ ] Logging configured and rotating
- [ ] Monitoring setup (metrics, alerts)
- [ ] Backup script scheduled
- [ ] Security hardening applied
- [ ] Documentation updated

---

## Getting Help

- Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Check [GitHub Issues](https://github.com/Eth3rnit3/FerrumMCP/issues)
- Email: [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com)

---

**Last Updated**: 2024-11-22
