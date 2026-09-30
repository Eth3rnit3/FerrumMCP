# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Hover over an element
    class HoverTool < BaseTool
      tool_name 'hover'
      description 'Hover over an element (CSS selector, XPath or snapshot ref)'

      param :selector, type: :string, required: true, description: 'Selector of the element to hover over'

      def perform(params)
        selector = params[:selector]
        logger.info "Hovering over element: #{selector}"

        element = find_element(selector)
        element.scroll_into_view

        begin
          element.hover
        rescue StandardError => e
          logger.debug "Native hover failed, using JavaScript: #{e.message}"
          page.execute(<<~JS, element)
            arguments[0].dispatchEvent(new MouseEvent('mouseover', { bubbles: true, cancelable: true, view: window }));
          JS
        end

        success_response(message: "Hovered over #{selector}")
      end
    end
  end
end
