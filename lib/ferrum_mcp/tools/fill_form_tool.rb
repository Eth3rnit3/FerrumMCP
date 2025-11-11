# frozen_string_literal: true

module FerrumMCP
  module Tools
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
  end
end
