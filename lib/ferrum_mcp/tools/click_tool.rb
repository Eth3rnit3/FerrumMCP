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
  end
end
