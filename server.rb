#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'optparse'
require_relative 'lib/ferrum_mcp'
require_relative 'lib/ferrum_mcp/transport/http_server'
require_relative 'lib/ferrum_mcp/transport/stdio_server'

# Parse command line options
options = {
  transport: 'http'
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
  opts.separator ''
  opts.separator 'Ferrum MCP Server - Browser automation server using Ferrum and BotBrowser'
  opts.separator ''
  opts.separator 'Options:'

  opts.on('-t', '--transport TRANSPORT', %w[http stdio],
          'Transport protocol to use (http or stdio)',
          '  http  - HTTP server (default)',
          '  stdio - Standard input/output') do |t|
    options[:transport] = t
  end

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end

  opts.on('-v', '--version', 'Show version') do
    puts "Ferrum MCP Server v#{FerrumMCP::VERSION}"
    exit
  end

  opts.separator ''
  opts.separator 'Environment variables:'
  opts.separator '  BROWSER_PATH        - Path to browser executable (optional)'
  opts.separator '  BOTBROWSER_PROFILE  - BotBrowser profile to use (optional)'
  opts.separator '  BROWSER_HEADLESS    - Run browser in headless mode (true/false)'
  opts.separator '  BROWSER_TIMEOUT     - Browser timeout in seconds'
  opts.separator '  SERVER_HOST         - HTTP server host (default: localhost)'
  opts.separator '  SERVER_PORT         - HTTP server port (default: 3000)'
  opts.separator '  LOG_LEVEL           - Log level (debug/info/warn/error)'
  opts.separator ''
  opts.separator 'Examples:'
  opts.separator "  #{$PROGRAM_NAME}                    # Start with HTTP transport"
  opts.separator "  #{$PROGRAM_NAME} --transport stdio  # Start with STDIO transport"
  opts.separator "  #{$PROGRAM_NAME} --help             # Show this help"
end.parse!

# Load environment variables from .env file if it exists
if File.exist?('.env')
  File.readlines('.env').each do |line|
    next if line.strip.empty? || line.start_with?('#')

    key, value = line.strip.split('=', 2)
    ENV[key] = value if key && value
  end
end

# Create configuration
config = FerrumMCP::Configuration.new(transport: options[:transport])

# Validate configuration
unless config.valid?
  puts 'ERROR: Invalid browser configuration'
  puts 'The specified BROWSER_PATH does not exist'
  puts ''
  puts 'Options:'
  puts '  1. Remove BROWSER_PATH to use system Chrome/Chromium'
  puts '  2. Set BROWSER_PATH to a valid browser executable'
  puts ''
  puts 'Example: export BROWSER_PATH=/path/to/chrome'
  exit 1
end

# Create server
mcp_server = FerrumMCP::Server.new(config)

# Create transport based on option
transport_server = case options[:transport]
                   when 'stdio'
                     FerrumMCP::Transport::StdioServer.new(mcp_server, config)
                   when 'http'
                     FerrumMCP::Transport::HTTPServer.new(mcp_server, config)
                   else
                     raise "Unknown transport: #{options[:transport]}"
                   end

# Signal handling
trap('INT') do
  config.logger.info 'Shutting down...'
  transport_server.stop
  mcp_server.stop_browser
  exit 0
end

trap('TERM') do
  config.logger.info 'Shutting down...'
  transport_server.stop
  mcp_server.stop_browser
  exit 0
end

# Start servers
begin
  # Log startup info to file only
  logger = config.logger
  logger.info '=' * 60
  logger.info "Ferrum MCP Server v#{FerrumMCP::VERSION}"
  logger.info '=' * 60
  logger.info ''
  logger.info 'Configuration:'

  # Display browsers
  logger.info "  Browsers (#{config.browsers.count}):"
  config.browsers.each do |browser|
    default_marker = browser == config.default_browser ? ' [default]' : ''
    browser_path = browser.path || 'auto-detect'
    logger.info "    - #{browser.id}: #{browser.name} (#{browser.type})#{default_marker}"
    logger.info "      Path: #{browser_path}"
  end

  # Display user profiles
  if config.user_profiles.any?
    logger.info "  User Profiles (#{config.user_profiles.count}):"
    config.user_profiles.each do |profile|
      logger.info "    - #{profile.id}: #{profile.name}"
      logger.info "      Path: #{profile.path}"
    end
  end

  # Display BotBrowser profiles
  if config.bot_profiles.any?
    logger.info '  BotBrowser (anti-detection enabled) ✓'
    logger.info "  Bot Profiles (#{config.bot_profiles.count}):"
    config.bot_profiles.each do |profile|
      encrypted_marker = profile.encrypted ? ' [encrypted]' : ''
      logger.info "    - #{profile.id}: #{profile.name}#{encrypted_marker}"
      logger.info "      Path: #{profile.path}"
    end
  else
    logger.info '  BotBrowser: Not configured (consider using for better stealth)'
  end

  logger.info "  Headless: #{config.headless}"
  logger.info "  Timeout: #{config.timeout}s"
  logger.info ''
  logger.info 'Transport:'
  logger.info "  Protocol: #{options[:transport].upcase}"

  if options[:transport] == 'http'
    logger.info "  Host: #{config.server_host}"
    logger.info "  Port: #{config.server_port}"
    logger.info "  MCP Endpoint: http://#{config.server_host}:#{config.server_port}/mcp"
  else
    logger.info '  Mode: Standard input/output'
  end

  logger.info ''
  logger.info '=' * 60
  logger.info 'Server starting...'
  logger.info '=' * 60
  logger.info ''

  transport_server.start

  # Keep main thread alive (not needed for stdio as it blocks)
  sleep if options[:transport] == 'http'
rescue StandardError => e
  logger = config.logger
  logger.error "ERROR: #{e.message}"
  logger.error e.backtrace.join("\n")
  exit 1
end
