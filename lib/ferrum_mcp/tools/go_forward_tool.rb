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
        { type: 'object', properties: {} }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Going forward'
        browser.forward

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue StandardError => e
        logger.error "Go forward failed: #{e.message}"
        error_response("Failed to go forward: #{e.message}")
      end
    end
  end
end
