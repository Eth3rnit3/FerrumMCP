# frozen_string_literal: true

require 'mcp'
require 'ferrum'
require 'logger'
require 'json'

# Main module for Ferrum MCP Server
module FerrumMCP
  class Error < StandardError; end
  class BrowserError < Error; end
  class ToolError < Error; end
end

require_relative 'ferrum_mcp/version'
require_relative 'ferrum_mcp/configuration'
require_relative 'ferrum_mcp/browser_manager'
require_relative 'ferrum_mcp/tools/base_tool'
require_relative 'ferrum_mcp/tools/navigation_tools'
require_relative 'ferrum_mcp/tools/interaction_tools'
require_relative 'ferrum_mcp/tools/extraction_tools'
require_relative 'ferrum_mcp/tools/waiting_tools'
require_relative 'ferrum_mcp/tools/advanced_tools'
require_relative 'ferrum_mcp/server'
