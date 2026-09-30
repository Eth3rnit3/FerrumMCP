# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Fill form fields
    class FillFormTool < BaseTool
      tool_name 'fill_form'
      description 'Fill one or more form fields with values (typing like a user)'

      param :fields, type: :array, required: true,
                     description: 'Array of fields to fill',
                     schema: {
                       items: {
                         type: 'object',
                         properties: {
                           selector: { type: 'string', description: 'CSS selector, XPath or snapshot ref' },
                           value: { type: 'string', description: 'Value to type' },
                           clear: { type: 'boolean', description: 'Clear the field first (default: false)' }
                         },
                         required: %w[selector value]
                       }
                     }

      def perform(params)
        fields = Array(params[:fields])
        results = []

        fields.each_with_index do |field, index|
          selector = field[:selector]
          logger.info "Filling field: #{selector}"

          with_retry do
            element = find_element(selector)
            element.scroll_into_view
            element.focus
            sleep 0.05 # let the focus event register before typing
            clear_field(element) if field[:clear]
            element.type(field[:value].to_s)
          end

          results << { selector: selector, filled: true }
          sleep 0.1 unless index == fields.length - 1 # let onChange/validation handlers run
        end

        success_response(fields: results)
      end

      private

      def clear_field(element)
        page.execute(<<~JS, element)
          const el = arguments[0];
          const setter = Object.getOwnPropertyDescriptor(el.__proto__, 'value')?.set;
          setter ? setter.call(el, '') : (el.value = '');
          el.dispatchEvent(new Event('input', { bubbles: true }));
        JS
      end
    end
  end
end
