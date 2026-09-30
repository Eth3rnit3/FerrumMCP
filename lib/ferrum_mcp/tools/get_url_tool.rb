# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Get current URL
    class GetURLTool < BaseTool
      tool_name 'get_url'
      description 'Get the current page URL'

      def perform(_params)
        ensure_browser_active
        success_response(url: page.url)
      end
    end
  end
end
