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
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['selector', 'session_id']
        }
      end

      def execute(params)
        selector = param(params, :selector)

        logger.info "Hovering over element: #{selector}"

        # First ensure element exists and is ready
        element = find_element(selector)

        # Scroll into view if supported
        element.scroll_into_view if element.respond_to?(:scroll_into_view)

        # Try native hover first, fallback to JavaScript
        begin
          element.hover
          logger.debug 'Native hover successful'
        rescue StandardError => e
          logger.debug "Native hover failed, using JavaScript: #{e.message}"
          hover_with_javascript(selector)
        end

        success_response(message: "Hovered over #{selector}")
      rescue StandardError => e
        logger.error "Hover failed: #{e.message}"
        error_response("Failed to hover: #{e.message}")
      end

      private

      def hover_with_javascript(selector)
        # Use inspect to properly escape the selector for JavaScript (prevents XSS)
        script = <<~JS
          const element = document.querySelector(#{selector.inspect});
          if (!element) {
            throw new Error('Element not found: ' + #{selector.inspect});
          }
          const event = new MouseEvent('mouseover', { bubbles: true, cancelable: true, view: window });
          element.dispatchEvent(event);
        JS

        browser.execute(script)
        logger.debug 'JavaScript hover successful'
      end
    end
  end
end
