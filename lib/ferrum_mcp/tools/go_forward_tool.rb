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
      end
    end
  end
end
