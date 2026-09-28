# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Close a tab
    class CloseTabTool < TabTool
      tool_name 'close_tab'
      description 'Close a tab (the current one by default). The last remaining tab cannot be closed.'

      param :tab_id, type: :string, description: 'tab_id of the tab to close (default: current tab)'
      param :index, type: :integer, description: 'Zero-based index of the tab to close (alternative to tab_id)'

      def perform(params)
        ensure_browser_active
        list = tabs
        raise ToolError, 'Cannot close the last tab of the session' if list.length <= 1

        tab = if params[:tab_id] || params[:index]
                find_tab(tab_id: params[:tab_id], index: params[:index])
              else
                current_tab
              end
        closing_current = tab.target_id == current_tab.target_id
        logger.info "Closing tab #{tab.target_id}"
        tab.close
        wait_until_gone(tab.target_id)

        @browser_manager.select_page(tabs.first) if closing_current
        success_response(closed_tab_id: tab.target_id, current_tab_id: current_tab.target_id, count: tabs.length)
      rescue StandardError => e
        logger.error "Close tab failed: #{e.message}"
        error_response("Failed to close tab: #{e.message}")
      end

      private

      # Target.closeTarget is asynchronous; wait for the browser to drop it
      def wait_until_gone(target_id, timeout: 2)
        deadline = monotonic_now + timeout
        sleep POLL_INTERVAL while monotonic_now < deadline && tabs.any? { |t| t.target_id == target_id }
      end
    end
  end
end
