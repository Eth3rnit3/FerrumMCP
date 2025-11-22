# frozen_string_literal: true

require_relative 'lib/ferrum_mcp/version'

Gem::Specification.new do |spec|
  spec.name = 'ferrum-mcp'
  spec.version = FerrumMCP::VERSION
  spec.authors = ['Eth3rnit3']
  spec.email = ['eth3rnit3@gmail.com']

  spec.summary = 'Browser automation server implementing the Model Context Protocol'
  spec.description = <<~DESC
    FerrumMCP is a browser automation server that implements the Model Context Protocol (MCP),
    enabling AI assistants to interact with web pages through a standardized interface.
    Features include navigation, form interaction, content extraction, screenshot capture,
    JavaScript execution, cookie management, and advanced capabilities like smart cookie banner
    detection and AI-powered CAPTCHA solving.
  DESC

  spec.homepage = 'https://github.com/Eth3rnit3/FerrumMCP'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/Eth3rnit3/FerrumMCP',
    'changelog_uri' => 'https://github.com/Eth3rnit3/FerrumMCP/blob/main/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/Eth3rnit3/FerrumMCP/issues',
    'documentation_uri' => 'https://github.com/Eth3rnit3/FerrumMCP/tree/main/docs',
    'rubygems_mfa_required' => 'true'
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob('{bin,lib,docs}/**/*', File::FNM_DOTMATCH).reject do |f|
    File.directory?(f)
  end + %w[
    README.md
    CHANGELOG.md
    CONTRIBUTING.md
    SECURITY.md
    LICENSE
    .env.example
    bin/ferrum-mcp
  ]

  spec.bindir = 'bin'
  spec.executables = ['ferrum-mcp']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'dotenv', '~> 3.1'
  spec.add_dependency 'ferrum', '~> 0.17.1'
  spec.add_dependency 'json', '~> 2.16'
  spec.add_dependency 'logger', '~> 1.7'
  spec.add_dependency 'mcp', '~> 0.4.0'
  spec.add_dependency 'puma', '~> 7.1'
  spec.add_dependency 'rack', '~> 3.2'
  spec.add_dependency 'ruby-vips', '~> 2.2'
  spec.add_dependency 'zeitwerk', '~> 2.7'

  # Post-install message
  spec.post_install_message = <<~MESSAGE

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    Thank you for installing FerrumMCP #{FerrumMCP::VERSION}!

    📚 Documentation: https://github.com/Eth3rnit3/FerrumMCP/tree/main/docs
    🚀 Quick Start:   https://github.com/Eth3rnit3/FerrumMCP/blob/main/docs/GETTING_STARTED.md
    🐛 Issues:        https://github.com/Eth3rnit3/FerrumMCP/issues

    To start the server:

      ferrum-mcp start [OPTIONS]

    For help:

      ferrum-mcp --help

    ⚠️  Requirements:
      - Chrome/Chromium browser must be installed
      - Optional: whisper-cli for CAPTCHA solving
      - Optional: BotBrowser for anti-detection

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  MESSAGE
end
