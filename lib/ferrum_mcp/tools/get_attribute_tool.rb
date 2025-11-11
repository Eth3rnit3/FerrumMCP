# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to get element attributes
    class GetAttributeTool < BaseTool
      def self.tool_name
        'get_attribute'
      end
    
      def self.description
        'Get attribute value(s) from an element'
      end
    
      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector of the element'
            },
            attribute: {
              type: 'string',
              description: 'Attribute name to get'
            }
          },
          required: %w[selector attribute]
        }
      end
    
      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]
        attribute = params['attribute'] || params[:attribute]
    
        logger.info "Getting attribute '#{attribute}' from: #{selector}"
        element = find_element(selector)
        value = element.attribute(attribute)
    
        success_response(
          selector: selector,
          attribute: attribute,
          value: value
        )
      rescue StandardError => e
        logger.error "Get attribute failed: #{e.message}"
        error_response("Failed to get attribute: #{e.message}")
      end
    end
  end
end
