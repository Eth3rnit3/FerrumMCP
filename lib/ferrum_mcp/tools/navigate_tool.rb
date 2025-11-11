# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to navigate to a URL
    class NavigateTool < BaseTool
      def self.tool_name
        'navigate'
      end

      def self.description
        'Navigate to a specific URL in the browser'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            url: {
              type: 'string',
              description: 'The URL to navigate to (must include protocol: http:// or https://)'
            }
          },
          required: ['url']
        }
      end

      def execute(params)
        ensure_browser_active
        url = params['url'] || params[:url]

        logger.info "Navigating to: #{url}"
        browser.goto(url)

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue StandardError => e
        logger.error "Navigation failed: #{e.message}"
        error_response("Failed to navigate: #{e.message}")
      end
    end
  end
end
