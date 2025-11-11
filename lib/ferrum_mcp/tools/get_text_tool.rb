# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to extract text from elements
    class GetTextTool < BaseTool
      def self.tool_name
        'get_text'
      end
    
      def self.description
        'Extract text content from one or more elements'
      end
    
      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector of element(s) to extract text from'
            },
            multiple: {
              type: 'boolean',
              description: 'Extract from all matching elements (default: false)',
              default: false
            }
          },
          required: ['selector']
        }
      end
    
      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]
        multiple = params['multiple'] || params[:multiple] || false
    
        logger.info "Extracting text from: #{selector}"
    
        if multiple
          elements = browser.css(selector)
          texts = elements.map(&:text)
          success_response(texts: texts, count: texts.length)
        else
          element = find_element(selector)
          success_response(text: element.text)
        end
      rescue StandardError => e
        logger.error "Get text failed: #{e.message}"
        error_response("Failed to get text: #{e.message}")
      end
    end
  end
end
