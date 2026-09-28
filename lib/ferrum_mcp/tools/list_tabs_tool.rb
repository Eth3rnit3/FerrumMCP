# frozen_string_literal: true

module FerrumMCP
  module Tools
    # List open tabs
    class ListTabsTool < TabTool
      tool_name 'list_tabs'
      description 'List the open tabs of the session with their tab_id, url and title; marks the current one'

      def perform(_params)
        ensure_browser_active
        list = tabs.map.with_index { |tab, index| describe(tab, index) }
        success_response(count: list.length, tabs: list)
      rescue StandardError => e
        logger.error "List tabs failed: #{e.message}"
        error_response("Failed to list tabs: #{e.message}")
      end
    end
  end
end
