# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to get HTML content
    class GetHTMLTool < BaseTool
      def self.tool_name
        'get_html'
      end

      def self.description
        'Get HTML content of the page or a specific element'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'Optional: CSS selector to get HTML of specific element'
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['session_id']
        }
      end

      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]

        if selector
          logger.info "Getting HTML of element: #{selector}"
          element = find_element(selector)
          html = element.property('outerHTML')
          success_response(html: html, selector: selector)
        else
          logger.info 'Getting page HTML'
          html = browser.body
          success_response(html: html, url: browser.url)
        end
      rescue StandardError => e
        logger.error "Get HTML failed: #{e.message}"
        error_response("Failed to get HTML: #{e.message}")
      end
    end
  end
end
