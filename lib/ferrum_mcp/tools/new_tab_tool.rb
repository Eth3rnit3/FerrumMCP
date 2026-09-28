# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Open a new tab
    class NewTabTool < TabTool
      tool_name 'new_tab'
      description 'Open a new tab (optionally at a URL) and make it the current tab'

      param :url, type: :string, description: 'Optional: URL to open in the new tab'

      def perform(params)
        ensure_browser_active
        url = params[:url]
        if url
          raise ToolError, 'URL must start with http:// or https://' unless %r{\Ahttps?://}.match?(url)

          @browser_manager.config.url_policy.check!(url)
        end

        logger.info "Opening new tab#{" at #{url}" if url}"
        tab = @browser_manager.create_page
        @browser_manager.select_page(tab)
        if url
          tab.goto(url)
          tab.network.wait_for_idle(timeout: 30)
        end

        success_response(tab_id: tab.target_id, url: tab.url, title: tab.title, count: tabs.length)
      rescue StandardError => e
        logger.error "New tab failed: #{e.message}"
        error_response("Failed to open tab: #{e.message}")
      end
    end
  end
end
