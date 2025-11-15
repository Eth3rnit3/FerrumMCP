# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to go back in browser history
    class GoBackTool < BaseTool
      def self.tool_name
        'go_back'
      end

      def self.description
        'Go back to the previous page in browser history'
      end

      def self.input_schema
        { type: 'object', properties: {} }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Going back'
        browser.back

        # Wait for network to be idle to ensure page is loaded
        browser.network.wait_for_idle(timeout: 30)

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue Ferrum::TimeoutError => e
        logger.error "Go back timeout: #{e.message}"
        error_response("Go back timed out: #{e.message}")
      rescue StandardError => e
        logger.error "Go back failed: #{e.message}"
        error_response("Failed to go back: #{e.message}")
      end
    end
  end
end
