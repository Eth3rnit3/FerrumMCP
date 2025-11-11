# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to refresh the current page
    class RefreshTool < BaseTool
      def self.tool_name
        'refresh'
      end
    
      def self.description
        'Refresh the current page'
      end
    
      def self.input_schema
        { type: 'object', properties: {} }
      end
    
      def execute(_params)
        ensure_browser_active
        logger.info 'Refreshing page'
        browser.refresh
    
        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue StandardError => e
        logger.error "Refresh failed: #{e.message}"
        error_response("Failed to refresh: #{e.message}")
      end
    end
  end
end
