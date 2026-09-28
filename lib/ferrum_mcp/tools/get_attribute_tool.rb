# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Get element attributes
    class GetAttributeTool < BaseTool
      tool_name 'get_attribute'
      description 'Get an attribute value from an element (CSS selector, XPath or snapshot ref)'

      param :selector, type: :string, required: true, description: 'Selector of the element'
      param :attribute, type: :string, required: true, description: 'Attribute name to read'

      def perform(params)
        ensure_browser_active
        selector = params[:selector]
        attribute = params[:attribute]
        logger.info "Getting attribute '#{attribute}' from: #{selector}"

        value = find_element(selector).attribute(attribute)
        success_response(selector: selector, attribute: attribute, value: value)
      rescue StandardError => e
        logger.error "Get attribute failed: #{e.message}"
        error_response("Failed to get attribute: #{e.message}")
      end
    end
  end
end
