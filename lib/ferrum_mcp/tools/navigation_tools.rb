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

    # Tool to go back in browser history
    class GoBackTool < BaseTool
      def self.tool_name
        'go_back'
      end

      def self.description
        'Go back to the previous page in browser history'
      end

      def self.input_schema
        { type: 'object', properties: {} }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Going back'
        browser.back

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue StandardError => e
        logger.error "Go back failed: #{e.message}"
        error_response("Failed to go back: #{e.message}")
      end
    end

    # Tool to go forward in browser history
    class GoForwardTool < BaseTool
      def self.tool_name
        'go_forward'
      end

      def self.description
        'Go forward to the next page in browser history'
      end

      def self.input_schema
        { type: 'object', properties: {} }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Going forward'
        browser.forward

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue StandardError => e
        logger.error "Go forward failed: #{e.message}"
        error_response("Failed to go forward: #{e.message}")
      end
    end

    # Tool to refresh the current page
    class RefreshTool < BaseTool
      def self.tool_name
        'refresh'
      end

      def self.description
        'Refresh the current page'
      end

      def self.input_schema
        { type: 'object', properties: {} }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Refreshing page'
        browser.refresh

        success_response(
          url: browser.url,
          title: browser.title
        )
      rescue StandardError => e
        logger.error "Refresh failed: #{e.message}"
        error_response("Failed to refresh: #{e.message}")
      end
    end
  end
end
