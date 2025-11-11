# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to click on an element
    class ClickTool < BaseTool
      def self.tool_name
        'click'
      end

      def self.description
        'Click on an element using a CSS selector'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector of the element to click'
            },
            wait: {
              type: 'number',
              description: 'Seconds to wait for element (default: 5)',
              default: 5
            }
          },
          required: ['selector']
        }
      end

      def execute(params)
        selector = params['selector'] || params[:selector]
        wait_time = params['wait'] || params[:wait] || 5

        logger.info "Clicking element: #{selector}"
        element = find_element(selector, timeout: wait_time)
        element.click

        success_response(message: "Clicked on #{selector}")
      rescue StandardError => e
        logger.error "Click failed: #{e.message}"
        error_response("Failed to click: #{e.message}")
      end
    end

    # Tool to fill form fields
    class FillFormTool < BaseTool
      def self.tool_name
        'fill_form'
      end

      def self.description
        'Fill one or more form fields with values'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            fields: {
              type: 'array',
              description: 'Array of fields to fill',
              items: {
                type: 'object',
                properties: {
                  selector: { type: 'string', description: 'CSS selector' },
                  value: { type: 'string', description: 'Value to fill' }
                },
                required: ['selector', 'value']
              }
            }
          },
          required: ['fields']
        }
      end

      def execute(params)
        fields = params['fields'] || params[:fields]
        results = []

        fields.each do |field|
          selector = field['selector'] || field[:selector]
          value = field['value'] || field[:value]

          logger.info "Filling field: #{selector}"
          element = find_element(selector)
          element.focus.type(value)
          results << { selector: selector, filled: true }
        end

        success_response(fields: results)
      rescue StandardError => e
        logger.error "Fill form failed: #{e.message}"
        error_response("Failed to fill form: #{e.message}")
      end
    end

    # Tool to press keyboard keys
    class PressKeyTool < BaseTool
      def self.tool_name
        'press_key'
      end

      def self.description
        'Press keyboard keys (e.g., Enter, Tab, Escape)'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            key: {
              type: 'string',
              description: 'Key to press (Enter, Tab, Escape, ArrowDown, etc.)'
            },
            selector: {
              type: 'string',
              description: 'Optional: CSS selector to focus before pressing key'
            }
          },
          required: ['key']
        }
      end

      def execute(params)
        key = params['key'] || params[:key]
        selector = params['selector'] || params[:selector]

        if selector
          logger.info "Focusing element: #{selector}"
          element = find_element(selector)
          element.focus
        end

        logger.info "Pressing key: #{key}"
        # Use down + up to simulate key press
        browser.keyboard.down(key)
        browser.keyboard.up(key)

        success_response(message: "Pressed key: #{key}")
      rescue StandardError => e
        logger.error "Press key failed: #{e.message}"
        error_response("Failed to press key: #{e.message}")
      end
    end

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
