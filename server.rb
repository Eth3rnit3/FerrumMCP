#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/ferrum_mcp'
require_relative 'lib/ferrum_mcp/transport/http_server'

# Load environment variables from .env file if it exists
if File.exist?('.env')
  File.readlines('.env').each do |line|
    next if line.strip.empty? || line.start_with?('#')

    key, value = line.strip.split('=', 2)
    ENV[key] = value if key && value
  end
end

# Create configuration
config = FerrumMCP::Configuration.new

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
http_server = FerrumMCP::Transport::HTTPServer.new(mcp_server, config)

# Signal handling
trap('INT') do
  puts "\n\nShutting down..."
  http_server.stop
  mcp_server.stop_browser
  exit 0
end

trap('TERM') do
  puts "\n\nShutting down..."
  http_server.stop
  mcp_server.stop_browser
  exit 0
end

# Start servers
begin
  puts '=' * 60
  puts "Ferrum MCP Server v#{FerrumMCP::VERSION}"
  puts '=' * 60
  puts ''
  puts 'Configuration:'

  if config.browser_path
    puts "  Browser: #{config.browser_path}"
  else
    puts '  Browser: System Chrome/Chromium (auto-detect)'
  end

  if config.using_botbrowser?
    puts '  Mode: BotBrowser (anti-detection enabled) ✓'
    puts "  Profile: #{config.botbrowser_profile}"
  else
    puts '  Mode: Standard Chrome'
    puts '  Profile: none (consider using BotBrowser for better stealth)'
  end

  puts "  Headless: #{config.headless}"
  puts "  Timeout: #{config.timeout}s"
  puts ''
  puts 'Server:'
  puts "  Host: #{config.server_host}"
  puts "  Port: #{config.server_port}"
  puts "  MCP Endpoint: http://#{config.server_host}:#{config.server_port}/mcp"
  puts ''
  puts '=' * 60
  puts 'Press Ctrl+C to stop'
  puts '=' * 60
  puts ''

  http_server.start

  # Keep main thread alive
  sleep
rescue StandardError => e
  puts "ERROR: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end
