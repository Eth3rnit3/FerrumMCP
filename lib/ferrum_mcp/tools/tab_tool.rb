# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Shared helpers for tab tools
    class TabTool < BaseTool
      protected

      def tabs
        @browser_manager.pages
      end

      def current_tab
        page
      end

      def describe(tab, index)
        { index: index, tab_id: tab.target_id, url: safe(tab, :url), title: safe(tab, :title),
          current: tab.target_id == current_tab.target_id }
      end

      # Find a tab by tab_id or zero-based index
      def find_tab(tab_id: nil, index: nil)
        list = tabs
        tab = if tab_id
                list.find { |t| t.target_id == tab_id }
              elsif index
                list[index.to_i]
              end
        tab || raise(ToolError, "Tab not found (#{tab_id ? "tab_id: #{tab_id}" : "index: #{index}"})")
      end

      def safe(tab, method)
        tab.public_send(method)
      rescue StandardError
        nil
      end
    end
  end
end
