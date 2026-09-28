# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Go back to the previous page in browser history
    class GoBackTool < BaseTool
      tool_name 'go_back'
      description 'Go back to the previous page in browser history'

      def perform(_params)
        ensure_browser_active
        logger.info 'Going back'
        page.back
        page.network.wait_for_idle(timeout: 30)

        success_response(url: page.url, title: page.title)
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
