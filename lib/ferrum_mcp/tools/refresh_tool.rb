# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Refresh the current page
    class RefreshTool < BaseTool
      tool_name 'refresh'
      description 'Refresh the current page'

      def perform(_params)
        ensure_browser_active
        logger.info 'Refreshing page'
        page.refresh
        page.network.wait_for_idle(timeout: 30)

        success_response(url: page.url, title: page.title)
      end
    end
  end
end
