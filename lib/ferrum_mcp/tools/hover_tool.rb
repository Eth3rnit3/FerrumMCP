# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to hover over an element
    class HoverTool < BaseTool
      def self.tool_name
        'hover'
      end

      def self.description
        'Hover over an element using a CSS selector'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector of the element to hover over'
            }
          },
          required: ['selector']
        }
      end

      def execute(params)
        selector = params['selector'] || params[:selector]

        logger.info "Hovering over element: #{selector}"

        # Use JavaScript to trigger mouseover event
        script = <<~JS
          const element = document.querySelector('#{selector.gsub("'", "\\'")}');
          if (element) {
            const event = new MouseEvent('mouseover', { bubbles: true, cancelable: true, view: window });
            element.dispatchEvent(event);
          }
        JS

        browser.execute(script)

        success_response(message: "Hovered over #{selector}")
      rescue StandardError => e
        logger.error "Hover failed: #{e.message}"
        error_response("Failed to hover: #{e.message}")
      end
    end
  end
end
