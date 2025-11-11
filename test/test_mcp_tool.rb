#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'mcp'
require 'json'

puts "=" * 60
puts "Test MCP Tool Return Format"
puts "=" * 60
puts ""

# Create a simple MCP server
mcp_server = MCP::Server.new(
  name: 'test-server',
  version: '1.0.0',
  instructions: 'Test server'
)

# Test different return formats
puts "Test 1: Returning a simple hash"
mcp_server.define_tool(
  name: 'test_hash',
  description: 'Returns a hash',
  input_schema: { type: 'object', properties: {} }
) do
  { message: 'Hello', status: 'ok' }
end

puts "Test 2: Returning a string"
mcp_server.define_tool(
  name: 'test_string',
  description: 'Returns a string',
  input_schema: { type: 'object', properties: {} }
) do
  'Hello World'
end

puts "Test 3: Raising an error"
mcp_server.define_tool(
  name: 'test_error',
  description: 'Raises an error',
  input_schema: { type: 'object', properties: {} }
) do
  raise StandardError, 'This is a test error'
end

# Test the tools
puts "\n--- Testing tool_hash ---"
begin
  request = {
    'jsonrpc' => '2.0',
    'method' => 'tools/call',
    'params' => { 'name' => 'test_hash', 'arguments' => {} },
    'id' => 1
  }
  result = mcp_server.handle_request(request)
  puts "Result: #{result.to_json}"
rescue StandardError => e
  puts "Error: #{e.class} - #{e.message}"
end

puts "\n--- Testing tool_string ---"
begin
  request = {
    'jsonrpc' => '2.0',
    'method' => 'tools/call',
    'params' => { 'name' => 'test_string', 'arguments' => {} },
    'id' => 2
  }
  result = mcp_server.handle_request(request)
  puts "Result: #{result.to_json}"
rescue StandardError => e
  puts "Error: #{e.class} - #{e.message}"
end

puts "\n--- Testing tool_error ---"
begin
  request = {
    'jsonrpc' => '2.0',
    'method' => 'tools/call',
    'params' => { 'name' => 'test_error', 'arguments' => {} },
    'id' => 3
  }
  result = mcp_server.handle_request(request)
  puts "Result: #{result.to_json}"
rescue StandardError => e
  puts "Error: #{e.class} - #{e.message}"
end

puts "\n" + "=" * 60
