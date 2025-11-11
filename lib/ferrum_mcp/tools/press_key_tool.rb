# frozen_string_literal: true

module FerrumMCP
  module Tools
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
  end
end
