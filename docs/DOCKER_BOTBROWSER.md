# BotBrowser in Docker

[BotBrowser](https://github.com/botswin/BotBrowser) is a Chromium build with native fingerprint spoofing. It needs **profiles** (`.enc` files) from the BotBrowser project; demo profiles make sessions unstable, use trial or paid ones.

## Image

`eth3rnit3/ferrum-mcp:botbrowser` (also `1.1.0-botbrowser`, `1.1-botbrowser`) is based on `ruby:3.3-slim` and contains BotBrowser at `/opt/botbrowser/chrome`, **no regular Chromium**. Everything in the [Docker guide](DOCKER.md) applies (non-root UID 1000, headless only, `seccomp=unconfined`, `LOG_FILE=stderr`).

## Run

Mount your profiles and declare them with `BOT_PROFILE_<ID>=path:name:description` (quote the value, it contains spaces):

```bash
docker run -d --name ferrum-botbrowser --security-opt seccomp=unconfined -p 3000:3000 \
  -e LOG_FILE=stderr \
  -v /path/to/profiles:/app/profiles:ro \
  -e "BOT_PROFILE_US=/app/profiles/us_chrome.enc:US Chrome:US fingerprint" \
  -e "BOT_PROFILE_EU=/app/profiles/eu_chrome.enc:EU Chrome:EU fingerprint" \
  eth3rnit3/ferrum-mcp:botbrowser
```

Then pick a profile per session. The browser is BotBrowser by default (its id is `default`, from `BOTBROWSER_PATH`), so no `browser_id` is needed. Profile ids are the lowercase `<ID>`:

```json
{ "name": "create_session", "arguments": { "bot_profile_id": "us" } }
```

No profile is applied unless you pass `bot_profile_id`. A profile whose file doesn't exist is silently skipped, so check the mount if fingerprints look wrong: `docker exec ferrum-botbrowser ls -la /app/profiles`. The `ferrum://bot-profiles` resource lists what the server sees.

## Build

The image downloads the BotBrowser `.deb` for the target architecture from the [botswin/BotBrowser releases](https://github.com/botswin/BotBrowser/releases):

```bash
docker build -f Dockerfile.with-botbrowser -t ferrum-mcp:botbrowser .
```

- **Version**: the latest upstream release by default, because old releases are removed upstream. Pin one with `--build-arg BOTBROWSER_VERSION=155.0.8059.5`.
- **Rate limit**: behind a shared IP the GitHub API may refuse the lookup; pass a token with `--secret id=github_token,env=GITHUB_TOKEN`.
- **Multi-arch**: `docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile.with-botbrowser .` (CI publishes both).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Session fails to start with `browser_id: "botbrowser"` | That id only exists if you define `BROWSER_BOTBROWSER`; omit `browser_id` or use `default` |
| Fingerprint is not the profile's | Pass `bot_profile_id`, and check the file exists in the container |
| Build fails with "No BotBrowser .deb for …" | The pinned release has no asset for that architecture; try another version |
| Build fails on the GitHub API | Rate limit: pass `--secret id=github_token,env=GITHUB_TOKEN` |
| Unstable sessions, crashes | Demo profiles; use a trial or paid profile |

Outside Docker, declare BotBrowser like any other browser: `BROWSER_BOTBROWSER=botbrowser:/path/to/chrome:BotBrowser:Anti-detection` (see [Configuration](CONFIGURATION.md)).
