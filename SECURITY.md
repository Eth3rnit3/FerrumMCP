# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Security Model and Trust Assumptions

FerrumMCP is designed to operate in **trusted environments** with the following security assumptions:

### Trust Model

1. **Trusted Environment**: FerrumMCP assumes it runs in a controlled environment where all clients are trusted
2. **No Public Exposure**: The server should NOT be exposed to the public internet without additional security layers
3. **Trusted Input**: Tool inputs are assumed to come from trusted AI assistants, not untrusted users
4. **Local Network**: HTTP transport is intended for localhost or private network use only

### What FerrumMCP Does NOT Provide

- ❌ **Authentication**: No API keys, tokens, or user authentication
- ❌ **Authorization**: No role-based access control or permissions
- ❌ **Rate Limiting**: No built-in protection against DoS attacks
- ❌ **Input Sanitization**: Limited validation of user-provided selectors and scripts
- ❌ **Audit Logging**: No security event logging or monitoring
- ❌ **Encryption**: No TLS/SSL for HTTP transport (use reverse proxy if needed)

### Security Boundaries

FerrumMCP provides security at the following levels:

✅ **Browser Sandbox**: Relies on Chrome's built-in sandbox for isolation
✅ **Thread Safety**: Mutex-protected session management prevents race conditions
✅ **Session Isolation**: Each browser session is isolated from others
✅ **Dependency Pinning**: All gems use pessimistic version constraints
✅ **Input Validation**: Session IDs and basic parameters are validated

## Known Security Considerations

### 1. Arbitrary JavaScript Execution

**Tools affected**: `execute_script`, `evaluate_js`

**Risk**: These tools allow execution of arbitrary JavaScript in the browser context.

**Mitigation**:
- Only use in trusted environments
- Do not expose to untrusted users
- Consider disabling these tools if not needed

### 2. File System Access

**Tools affected**: `screenshot`, potential future download features

**Risk**: Screenshots are saved to disk and could fill storage or access sensitive paths.

**Mitigation**:
- Screenshots are temporary and base64-encoded
- No direct file path control by users
- Consider implementing storage quotas

### 3. Network Access

**Tools affected**: `navigate`, all browser operations

**Risk**: Browser can access arbitrary URLs including internal networks.

**Mitigation**:
- Use browser's built-in protections
- Consider firewall rules to restrict browser network access
- Monitor for suspicious navigation patterns

### 4. XPath Injection

**Tools affected**: `find_by_text`

**Risk**: User-provided text could manipulate XPath queries.

**Mitigation**:
- Partial escaping implemented for quotes
- Use CSS selectors when possible
- Full XPath sanitization planned for v1.1

### 5. Session Resource Exhaustion

**Risk**: Unlimited session creation could exhaust system resources (DoS).

**Current Status**: No hard limits enforced
**Planned**: `MAX_CONCURRENT_SESSIONS` configuration in v1.1

**Temporary Mitigation**:
- Sessions auto-close after 30 minutes idle
- Background cleanup every 5 minutes
- Monitor session count via `list_sessions`

### 6. Docker Root Execution

**Risk**: Docker container runs as root by default.

**Current Status**: No USER directive in Dockerfile
**Planned**: Non-root user in v1.1

**Temporary Mitigation**:
- Use Docker user namespaces
- Run with `--user` flag: `docker run --user 1000:1000 ...`
- Apply SELinux or AppArmor policies

### 7. Cookie and Credential Exposure

**Tools affected**: `get_cookies`, `set_cookie`

**Risk**: Cookies containing session tokens or credentials could be extracted.

**Mitigation**:
- Use httpOnly and secure flags when setting cookies
- Consider restricting cookie access to specific domains
- Avoid storing sensitive data in cookies

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
The execute_script tool does not validate JavaScript syntax, allowing
injection of malicious code that could access internal network services.

Impact:
An attacker could use the browser to scan internal networks or exfiltrate
data from internal services.

Affected Versions: 0.1.0

Reproduction Steps:
1. Create a session: create_session(headless: false)
2. Execute: execute_script("fetch('http://internal-server/secrets')", session_id)
3. Browser makes request to internal server

Suggested Fix:
Implement URL allowlist or blocklist for browser network access.
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
✅ **Browser sandboxing**: Ensure Chrome sandbox is enabled
✅ **Timeouts**: Set appropriate `BROWSER_TIMEOUT` values
✅ **Headless mode**: Use `BROWSER_HEADLESS=true` in production

## Security Roadmap

Planned security improvements for future versions:

### v1.1 (Planned)
- [ ] Session limits (`MAX_CONCURRENT_SESSIONS`)
- [ ] Rate limiting for HTTP transport
- [ ] XPath input sanitization
- [ ] Non-root Docker user
- [ ] Health check endpoint with optional authentication

### v1.2 (Planned)
- [ ] Optional API key authentication
- [ ] Tool-level permissions system
- [ ] Audit logging for security events
- [ ] URL allowlist/blocklist for navigation
- [ ] Resource usage quotas

### v2.0 (Future)
- [ ] Role-based access control (RBAC)
- [ ] TLS/SSL for HTTP transport
- [ ] Session encryption at rest
- [ ] Security event webhooks
- [ ] Integration with SIEM systems

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

**Last Updated**: 2024-11-22
**Version**: 1.0
