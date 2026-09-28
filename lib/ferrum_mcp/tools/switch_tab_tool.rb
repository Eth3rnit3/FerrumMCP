# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Switch the current tab
    class SwitchTabTool < TabTool
      tool_name 'switch_tab'
      description 'Make another tab the current one, by tab_id (from list_tabs) or zero-based index'

      param :tab_id, type: :string, description: 'tab_id of the tab to activate'
      param :index, type: :integer, description: 'Zero-based index of the tab to activate (alternative to tab_id)'

      def perform(params)
        ensure_browser_active
        raise ToolError, 'Provide tab_id or index' if params[:tab_id].nil? && params[:index].nil?

        tab = find_tab(tab_id: params[:tab_id], index: params[:index])
        @browser_manager.select_page(tab)
        tab.command('Page.bringToFront')
        logger.info "Switched to tab #{tab.target_id}"

        success_response(tab_id: tab.target_id, url: tab.url, title: tab.title)
      rescue StandardError => e
        logger.error "Switch tab failed: #{e.message}"
        error_response("Failed to switch tab: #{e.message}")
      end
    end
  end
end
