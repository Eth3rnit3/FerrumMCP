#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/ferrum_mcp'

puts "=" * 60
puts "Test MCP Tool Execution Directly"
puts "=" * 60
puts ""

# Create configuration and server
config = FerrumMCP::Configuration.new
config.log_level = :debug

server = FerrumMCP::Server.new(config)

puts "Testing navigate tool..."
puts ""

begin
  # Simulate what MCP does
  tool_class = FerrumMCP::Tools::NavigateTool
  params = { 'url' => 'https://www.example.com' }

  puts "1. Calling execute_tool..."
  result = server.send(:execute_tool, tool_class, params)

  puts "2. Result class: #{result.class}"
  puts "3. Result: #{result.inspect}"

  puts "4. Calling .to_h on result..."
  hash_result = result.to_h
  puts "5. Hash result: #{hash_result.inspect}"

  puts ""
  puts "SUCCESS!"

rescue StandardError => e
  puts ""
  puts "ERROR: #{e.class} - #{e.message}"
  puts ""
  puts "Backtrace:"
  puts e.backtrace.first(15).join("\n")
ensure
  server.stop_browser if server.browser_manager.active?
end
