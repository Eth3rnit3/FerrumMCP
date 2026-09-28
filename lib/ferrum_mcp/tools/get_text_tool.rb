# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Extract text from elements
    class GetTextTool < BaseTool
      tool_name 'get_text'
      description 'Extract text content from one or more elements (CSS selector, XPath or snapshot ref)'

      param :selector, type: :string, required: true, description: 'Selector of the element(s) to extract text from'
      param :multiple, type: :boolean, default: false,
                       description: 'Extract from all matching elements (default: false)'
      param :wait, type: :number, default: 5, description: 'Seconds to wait for the element (default: 5)'

      def perform(params)
        ensure_browser_active
        selector = params[:selector]
        logger.info "Extracting text from: #{selector}"

        find_element(selector, timeout: params[:wait])
        elements = find_elements(selector)

        if params[:multiple]
          texts = elements.map(&:text)
          success_response(texts: texts, count: texts.length)
        else
          success_response(text: elements.first.text)
        end
      rescue StandardError => e
        logger.error "Get text failed: #{e.message}"
        error_response("Failed to get text: #{e.message}")
      end
    end
  end
end
