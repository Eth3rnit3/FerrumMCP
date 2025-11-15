# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to go forward in browser history
    class GoForwardTool < BaseTool
      def self.tool_name
        'go_forward'
      end

      def self.description
        'Go forward to the next page in browser history'
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
        logger.info 'Going forward'
        browser.forward

        # Wait for network to be idle to ensure page is loaded
        browser.network.wait_for_idle(timeout: 30)

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue Ferrum::TimeoutError => e
        logger.error "Go forward timeout: #{e.message}"
        error_response("Go forward timed out: #{e.message}")
      rescue StandardError => e
        logger.error "Go forward failed: #{e.message}"
        error_response("Failed to go forward: #{e.message}")
      end
    end
  end
end
