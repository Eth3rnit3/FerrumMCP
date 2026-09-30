# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Get page title
    class GetTitleTool < BaseTool
      tool_name 'get_title'
      description 'Get the title of the current page'

      def perform(_params)
        ensure_browser_active
        success_response(title: page.title, url: page.url)
      end
    end
  end
end
