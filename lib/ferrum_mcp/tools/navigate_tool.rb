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
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['url', 'session_id']
        }
      end

      def execute(params)
        ensure_browser_active
        url = param(params, :url)

        # Validate URL format
        raise ToolError, 'URL must start with http:// or https://' unless %r{^https?://}.match?(url)

        logger.info "Navigating to: #{url}"
        browser.goto(url)

        # Wait for network to be idle to ensure page is loaded
        # This prevents race conditions with subsequent tool calls
        browser.network.wait_for_idle(timeout: 30)

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue Ferrum::TimeoutError => e
        logger.error "Navigation timeout: #{e.message}"
        error_response("Navigation timed out: #{e.message}")
      rescue StandardError => e
        logger.error "Navigation failed: #{e.message}"
        error_response("Failed to navigate: #{e.message}")
      end
    end
  end
end
