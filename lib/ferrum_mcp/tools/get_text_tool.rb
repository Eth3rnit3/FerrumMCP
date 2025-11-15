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
              description: 'CSS selector or XPath of element(s) to extract text from (use xpath: prefix for XPath)'
            },
            multiple: {
              type: 'boolean',
              description: 'Extract from all matching elements (default: false)',
              default: false
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['selector', 'session_id']
        }
      end

      def execute(params)
        ensure_browser_active
        selector = param(params, :selector)
        multiple = param(params, :multiple) || false

        logger.info "Extracting text from: #{selector}"

        # Support both CSS and XPath selectors
        if selector.start_with?('xpath:', '//')
          xpath = selector.sub(/^xpath:/, '')
          logger.debug "Using XPath: #{xpath}"
          elements = browser.xpath(xpath)
          raise ToolError, "Element not found with XPath: #{xpath}" if elements.empty?
        else
          elements = browser.css(selector)
          raise ToolError, "Element not found: #{selector}" if elements.empty?
        end

        if multiple
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
