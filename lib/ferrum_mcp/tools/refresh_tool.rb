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
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['session_id']
        }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Refreshing page'
        browser.refresh

        # Wait for network to be idle to ensure page is reloaded
        browser.network.wait_for_idle(timeout: 30)

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue Ferrum::TimeoutError => e
        logger.error "Refresh timeout: #{e.message}"
        error_response("Refresh timed out: #{e.message}")
      rescue StandardError => e
        logger.error "Refresh failed: #{e.message}"
        error_response("Failed to refresh: #{e.message}")
      end
    end
  end
end
