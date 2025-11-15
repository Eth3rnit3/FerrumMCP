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
                required: %w[selector value]
              }
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['fields', 'session_id']
        }
      end

      def execute(params)
        fields = param(params, :fields)
        results = []

        fields.each_with_index do |field, index|
          selector = field['selector'] || field[:selector]
          value = field['value'] || field[:value]

          logger.info "Filling field: #{selector}"

          # Use retry logic for stale elements
          with_retry do
            element = find_element(selector)

            # Scroll into view to ensure element is visible
            element.scroll_into_view if element.respond_to?(:scroll_into_view)

            # Focus with small delay to allow focus event to register
            element.focus
            sleep 0.05

            # Type the value
            element.type(value)
          end

          results << { selector: selector, filled: true }

          # Small delay between fields to allow validation/autocomplete/onChange handlers
          sleep 0.1 unless index == fields.length - 1
        end

        success_response(fields: results)
      rescue StandardError => e
        logger.error "Fill form failed: #{e.message}"
        error_response("Failed to fill form: #{e.message}")
      end
    end
  end
end
