---
layout: home

hero:
  name: FerrumMCP
  text: A real Chrome for your AI assistant
  tagline: An MCP server to navigate, click, fill forms, read pages, take screenshots, and get past cookie banners and CAPTCHAs. Built on Ferrum.
  actions:
    - theme: brand
      text: Get started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /reference/
    - theme: alt
      text: GitHub
      link: https://github.com/Eth3rnit3/FerrumMCP

features:
  - title: 40 agent-friendly tools
    details: snapshot lists interactive elements with stable refs (ref:e12) that every other tool accepts.
    link: /reference/
  - title: Parallel sessions
    details: Several browsers side by side, each with its own browser, profile and flags.
    link: /reference/sessions
  - title: Looks like a stock Chrome
    details: No automation flags, WebGL on, regular user agent even headless. BotBrowser supported as just another browser.
    link: /guide/configuration
  - title: CAPTCHAs, honestly
    details: Turnstile, reCAPTCHA v2 (audio, local whisper.cpp) and hCaptcha checkbox. When it can't solve, it says why.
    link: /reference/interaction#solve_captcha
  - title: STDIO or HTTP
    details: Plug it into Claude Code or Claude Desktop, or run the HTTP server with bearer auth and rate limiting.
    link: /guide/getting-started
  - title: Gem or Docker
    details: gem install ferrum-mcp, or run the eth3rnit3/ferrum-mcp image.
    link: /deployment/docker
---
