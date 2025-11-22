# frozen_string_literal: true

require 'mcp'
require 'ferrum'
require 'logger'
require 'json'
require 'zeitwerk'

# Setup Zeitwerk loader
loader = Zeitwerk::Loader.for_gem

# Custom inflector for acronyms
loader.inflector.inflect(
  'ferrum_mcp' => 'FerrumMCP',
  'mcp' => 'MCP',
  'cli' => 'CLI',
  'get_html_tool' => 'GetHTMLTool',
  'get_url_tool' => 'GetURLTool',
  'evaluate_js_tool' => 'EvaluateJSTool',
  'http_server' => 'HTTPServer',
  'query_shadow_dom_tool' => 'QueryShadowDOMTool'
)

loader.setup

# Main module for Ferrum MCP Server
module FerrumMCP
  class Error < StandardError; end
  class BrowserError < Error; end
  class ToolError < Error; end
end

# Eager load disabled to avoid circular loading when required from CLI
# loader.eager_load unless ENV['RACK_ENV'] == 'development'
