# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| < 1.1   | Upgrade to the current release |

## Security Model and Trust Assumptions

FerrumMCP is designed to operate in **trusted environments** with the following security assumptions:

### Trust Model

1. **Trusted Environment**: FerrumMCP assumes it runs in a controlled environment where all clients are trusted
2. **No Public Exposure**: The server should NOT be exposed to the public internet without additional security layers
3. **Trusted Input**: Tool inputs are assumed to come from trusted AI assistants, not untrusted users
4. **Local Network**: HTTP transport is intended for localhost or private network use only. It listens on
   `0.0.0.0` by default; set `MCP_SERVER_HOST=127.0.0.1` for local-only access.
5. **Shared Authority**: All configured API keys access the same browser sessions, profiles and tools.
   A browser session is not an authorization boundary between users. Run separate instances for clients
   that must not access one another's sessions.

### What FerrumMCP Does NOT Provide

- ❌ **Per-user Authorization**: No session ownership, role-based access control or tool permissions
- ❌ **Complete Network Isolation**: URL checks do not enforce a browser-wide network policy
- ❌ **Complete DoS Protection**: Request and session limits do not cap browser CPU, memory or tab count
- ❌ **Input Sanitization**: Limited validation of user-provided selectors and scripts
- ❌ **Audit Logging**: No security event logging or monitoring
- ❌ **Encryption**: No TLS/SSL for HTTP transport (use reverse proxy if needed)

### Security Boundaries

FerrumMCP provides security at the following levels:

✅ **Optional HTTP Authentication**: Set `API_KEY_ENABLED=true` and `API_KEY` or `API_KEYS` for Bearer
authentication on `/mcp`. HTTP startup fails if authentication is enabled without keys. `/health` and `/`
remain unauthenticated. Authentication is disabled by default and does not apply to STDIO.

✅ **DNS Rebinding Protection**: The HTTP endpoint validates Host and browser Origin headers by default.
Use `MCP_ALLOWED_HOSTS` / `MCP_ALLOWED_ORIGINS` for explicitly trusted hosts and origins.

✅ **Request and Session Limits**: HTTP rate limiting is enabled by default (100 requests per IP per
60 seconds), with atomic admission of concurrent requests. `MAX_CONCURRENT_SESSIONS` defaults to 10.
Only enable `TRUST_PROXY` behind a proxy you control.

✅ **Browser Sessions**: Each session has its own browser and mutex. Persistent profiles can be reused;
they and the server's files remain available to trusted clients.

✅ **Upload Restrictions**: `upload_file` resolves real paths and restricts them to `UPLOAD_ALLOWED_DIRS`,
defaulting to the working directory and system temp directory.

✅ **Browser Sandbox**: Desktop Chrome normally keeps its sandbox. The default flags disable it in
Docker, CI and root execution; the Docker images run as a non-root user. Treat container and network
isolation as essential when browsing untrusted pages in those environments.

✅ **Dependency Constraints**: Runtime gems use pessimistic version constraints; the repository lockfile
pins the versions used for development and Docker builds.

## Known Security Considerations

### 1. Arbitrary JavaScript Execution

**Tools affected**: `execute_script`, `evaluate_js`

**Risk**: These tools allow execution of arbitrary JavaScript in the browser context.

**Mitigation**:
- Only use in trusted environments
- Do not expose to untrusted users
- Consider disabling these tools if not needed

### 2. File System Access

**Tools affected**: `upload_file`, `create_session`

**Risk**: Trusted clients can upload permitted local files and select browser executables, profiles and
command-line options. The default upload directories may contain credentials or other sensitive files.

**Mitigation**:
- Set `UPLOAD_ALLOWED_DIRS` to a dedicated directory containing only intended upload files
- Run with minimal filesystem privileges and separate profiles for separate trust boundaries
- Screenshots are returned as in-memory base64 images; clients cannot select an output file path

### 3. Network Access

**Tools affected**: `navigate`, all browser operations

**Risk**: Browser can access arbitrary URLs including internal networks.

**Mitigation**:
- `ALLOWED_HOSTS` / `BLOCKED_HOSTS` check the initial URL in `navigate` and `new_tab` only
- These checks do not resolve DNS or cover redirects, link clicks, subresources or JavaScript requests
- Enforce private-network restrictions with a firewall, network namespace or an outbound proxy
- Monitor for suspicious navigation patterns

### 4. Selectors and Scripts

**Tools affected**: All tools accepting selectors, `execute_script`, `evaluate_js`

**Risk**: CSS, XPath and JavaScript inputs intentionally give clients broad control of the page.

**Mitigation**:
- `find_by_text` passes search text as a JavaScript argument rather than interpolating it into XPath
- Selector support is not a permissions system; only accept clients allowed to control the entire browser

### 5. Session Resource Exhaustion

**Risk**: Browsers and tabs can consume substantial CPU, memory and disk even within the session limit.

**Current Status**: `MAX_CONCURRENT_SESSIONS` defaults to 10. HTTP requests are rate limited by IP.

**Mitigation**:
- Sessions auto-close after 30 minutes idle
- Background cleanup every 5 minutes
- Monitor session count via `list_sessions`
- Set container memory/CPU limits and a session limit appropriate to the machine

### 6. Docker Browser Isolation

**Risk**: Docker Chrome runs with `--no-sandbox`; the documented deployment uses an unconfined seccomp
profile for Chrome compatibility.

**Current Status**: Both Dockerfiles run the server as the non-root `ferrum` user.

**Mitigation**:
- Use Docker user namespaces
- Avoid mounting sensitive host directories or sharing profiles with unrelated applications
- Apply SELinux or AppArmor policies

### 7. Cookie and Credential Exposure

**Tools affected**: `snapshot`, `get_cookies`, `get_html`, `get_attribute`, `evaluate_js`

**Risk**: Browser tools can expose cookies, tokens, form values and other page data to the MCP client.
HttpOnly protects a cookie from page JavaScript, not from an authorized browser automation client.

**Mitigation**:
- `snapshot` omits password-input values in both text and JSON formats, while preserving the controls
- Tool arguments and MCP exception request contexts are not dumped into logs
- URLs, selectors and error messages can still contain sensitive data; protect logs and avoid secrets in URLs
- Raw HTML, explicit attribute reads, scripts and cookie tools retain their intended access to browser data
- Use dedicated profiles and grant access only to clients trusted with their credentials

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow responsible disclosure:

### How to Report

**Email**: [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com)

**Subject**: `[SECURITY] FerrumMCP Vulnerability Report`

### What to Include

Please provide as much information as possible:

1. **Description**: Clear description of the vulnerability
2. **Impact**: What can an attacker do with this vulnerability?
3. **Affected Versions**: Which versions are affected?
4. **Reproduction Steps**: Detailed steps to reproduce the issue
5. **Proof of Concept**: Code or commands demonstrating the vulnerability (if applicable)
6. **Suggested Fix**: Any ideas for fixing the issue (optional)

### Example Report

```
Subject: [SECURITY] FerrumMCP Vulnerability Report

Description:
Describe a behavior that violates a documented security boundary, such as
an unauthenticated request accepted when API key authentication is configured.

Impact:
Explain which data or browser actions become accessible and to whom.

Affected Versions: Include the installed gem version or Git commit.

Reproduction Steps:
Include the configuration, request and observed response using dummy secrets.

Suggested Fix:
Describe how to preserve the intended security boundary.
```

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - **Critical**: Emergency patch within 7 days
  - **High**: Patch within 30 days
  - **Medium**: Patch in next minor release
  - **Low**: Patch in next release

### Disclosure Policy

- **Coordination**: We will work with you to understand and fix the issue
- **Credit**: You will be credited in the security advisory (unless you prefer to remain anonymous)
- **Public Disclosure**: We will coordinate public disclosure timing with you
- **CVE Assignment**: We will request CVE assignment for confirmed vulnerabilities
- **Security Advisory**: Published on GitHub Security Advisories

### What Happens Next

1. **Acknowledgment**: We confirm receipt of your report
2. **Validation**: We validate and reproduce the vulnerability
3. **Assessment**: We assess severity using CVSS scoring
4. **Development**: We develop and test a fix
5. **Notification**: We notify you when fix is ready
6. **Release**: We release patched version
7. **Disclosure**: We publish security advisory with your credit

## Security Best Practices

If you're deploying FerrumMCP, follow these best practices:

### Network Security

✅ **Bind to localhost**: Use `MCP_SERVER_HOST=127.0.0.1` for local-only access
✅ **Authenticate remote clients**: Set `API_KEY_ENABLED=true` and configure `API_KEY` or `API_KEYS`
✅ **DNS rebinding protection**: on by default, `/mcp` only accepts loopback `Host` headers and same-origin browser requests; list other names in `MCP_ALLOWED_HOSTS` / `MCP_ALLOWED_ORIGINS`
✅ **Use firewall**: Restrict access to port 3000
✅ **Reverse proxy**: Use nginx/Apache with TLS for remote access
✅ **VPN/SSH tunnel**: For remote access, use VPN or SSH tunneling

### Deployment Security

✅ **Minimal privileges**: Run as non-root user
✅ **Resource limits**: Set ulimits for memory and CPU
✅ **Read-only filesystem**: Mount system directories read-only in Docker
✅ **Secrets management**: Use environment variables, not config files
✅ **Update regularly**: Keep FerrumMCP and dependencies updated

### Monitoring

✅ **Session monitoring**: Track active sessions via `list_sessions`
✅ **Log monitoring**: Monitor `logs/ferrum_mcp.log` for errors
✅ **Resource monitoring**: Watch CPU, memory, and disk usage
✅ **Network monitoring**: Monitor browser network activity

### Configuration

✅ **Disable unused tools**: Remove tools you don't need from `TOOL_CLASSES`
✅ **Browser isolation**: Keep Chrome sandboxing where supported; isolate Docker browser network and filesystem access
✅ **Timeouts**: Set appropriate `BROWSER_TIMEOUT` values
✅ **Headless mode**: Use `BROWSER_HEADLESS=true` in production

## Security Roadmap

Potential future improvements (not currently provided):

- Per-client session ownership and tool-level permissions
- Browser-wide outbound network policy
- Browser resource and tab quotas
- Dedicated audit logging and monitoring integrations
- Optional authentication for health and information endpoints

## Acknowledgments

We thank the following security researchers for responsible disclosure:

- *No vulnerabilities reported yet*

## Contact

For security-related questions or concerns:

- **Security Email**: [eth3rnit3@gmail.com](mailto:eth3rnit3@gmail.com)
- **GitHub Issues**: For non-security bugs only
- **GitHub Discussions**: For general questions

## Legal

By reporting a vulnerability, you agree to:

- Give us reasonable time to fix the issue before public disclosure
- Not exploit the vulnerability beyond proof of concept
- Not access, modify, or delete data belonging to others

We commit to:

- Acknowledge your report within 48 hours
- Keep you informed of our progress
- Credit you in the security advisory (if you wish)
- Not pursue legal action for responsible disclosure

---

**Last Updated**: 2026-10-01
