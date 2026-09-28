# frozen_string_literal: true

# Drives a FerrumMCP server over stdio and fails loudly if a real browser
# round-trip does not work. Usage: ruby mcp_smoke_test.rb <command...>
#   ruby .github/scripts/mcp_smoke_test.rb docker run --rm -i IMAGE bin/ferrum-mcp start --transport stdio
require 'json'
require 'open3'

abort 'usage: mcp_smoke_test.rb <server command...>' if ARGV.empty?

stdin, stdout, stderr_thread = Open3.popen3(*ARGV).then { |i, o, e, _w| [i, o, Thread.new { e.read }] }
next_id = 0

request = lambda do |method, params = {}|
  next_id += 1
  stdin.puts({ jsonrpc: '2.0', id: next_id, method: method, params: params }.to_json)
  stdin.flush
  line = stdout.gets or abort("server closed stdout during #{method}\n#{stderr_thread.value}")
  JSON.parse(line)
end

call_tool = lambda do |name, arguments|
  response = request.call('tools/call', { name: name, arguments: arguments })
  result = response['result'] || abort("#{name}: JSON-RPC error #{response['error']}")
  content = result['content'].first
  abort("#{name} failed: #{content['text']}") if result['isError']
  puts "ok  #{name}"
  content['type'] == 'text' ? JSON.parse(content['text']) : content
end

request.call('initialize', { protocolVersion: '2025-06-18', capabilities: {},
                             clientInfo: { name: 'ci-smoke', version: '1' } })
tools = request.call('tools/list')['result']['tools'].map { |t| t['name'] }
abort "expected at least 40 tools, got #{tools.size}" if tools.size < 40
puts "ok  tools/list (#{tools.size} tools)"

session_id = call_tool.call('create_session', { headless: true })['session_id']
call_tool.call('navigate', { session_id: session_id, url: 'https://example.com' })
snapshot = call_tool.call('snapshot', { session_id: session_id })['snapshot']
abort "unexpected snapshot:\n#{snapshot}" unless snapshot.include?('Example Domain')
text = call_tool.call('get_text', { session_id: session_id, selector: 'h1' })['text']
abort "unexpected h1 text: #{text.inspect}" unless text == 'Example Domain'
image = call_tool.call('screenshot', { session_id: session_id })
abort 'screenshot is not an image' unless image['type'] == 'image'
call_tool.call('close_session', { session_id: session_id })

stdin.close
puts 'smoke test passed'
