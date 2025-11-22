---
name: Bug Report
about: Create a report to help us improve FerrumMCP
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

**Clear and concise description of the bug**

## Steps to Reproduce

1. Create session with '...'
2. Navigate to '...'
3. Execute tool '...'
4. See error

## Expected Behavior

A clear description of what you expected to happen.

## Actual Behavior

A clear description of what actually happened.

## Environment

- **FerrumMCP Version**: (e.g., v0.1.0)
- **Ruby Version**: (run `ruby --version`)
- **OS**: (e.g., macOS 14.1, Ubuntu 22.04)
- **Browser**: (e.g., Chrome 119.0.6045.199)
- **Deployment**: (Docker, systemd, local, K8s)
- **Transport**: (HTTP or STDIO)

## Configuration

**.env file** (redact sensitive info):
```bash
BROWSER_HEADLESS=true
LOG_LEVEL=info
# ... other relevant config
```

## Logs

**Relevant logs from `logs/ferrum_mcp.log`** (redact sensitive info):
```
ERROR -- : [error message here]
```

## Screenshots

If applicable, add screenshots to help explain your problem.

## Additional Context

Add any other context about the problem here:
- Does it happen consistently or intermittently?
- Did it work before? When did it break?
- Any workarounds you've found?

## Possible Solution

(Optional) If you have suggestions on how to fix this bug
