# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Go forward to the next page in browser history
    class GoForwardTool < BaseTool
      tool_name 'go_forward'
      description 'Go forward to the next page in browser history'

      def perform(_params)
        ensure_browser_active
        logger.info 'Going forward'
        page.forward
        page.network.wait_for_idle(timeout: 30)

        success_response(url: page.url, title: page.title)
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
