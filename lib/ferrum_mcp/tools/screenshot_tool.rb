# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to take screenshots
    class ScreenshotTool < BaseTool
      def self.tool_name
        'screenshot'
      end

      def self.description
        'Take a screenshot of the page or a specific element'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'Optional: CSS selector to screenshot specific element'
            },
            full_page: {
              type: 'boolean',
              description: 'Capture full scrollable page (default: false)',
              default: false
            },
            format: {
              type: 'string',
              enum: %w[png jpeg],
              description: 'Image format (default: png)',
              default: 'png'
            }
          }
        }
      end

      def execute(params)
        ensure_browser_active
        selector = param(params, :selector)
        full_page = param(params, :full_page) || false
        format = param(params, :format) || 'png'

        logger.info 'Taking screenshot'

        # If selector provided, verify element exists and is visible
        if selector
          element = find_element(selector)
          element.scroll_into_view if element.respond_to?(:scroll_into_view)

          # Small delay to ensure element is fully rendered
          sleep 0.1
        end

        # Request binary encoding from Ferrum (by default it returns base64)
        options = { format: format, full: full_page, encoding: :binary }

        # Add selector to options if provided
        options[:selector] = selector if selector

        screenshot_data = browser.screenshot(**options)

        # Now encode the binary data to base64 for MCP
        base64_data = Base64.strict_encode64(screenshot_data)
        mime_type = format == 'png' ? 'image/png' : 'image/jpeg'

        # Use image_response for MCP image injection
        image_response(base64_data, mime_type)
      rescue StandardError => e
        logger.error "Screenshot failed: #{e.message}"
        error_response("Failed to take screenshot: #{e.message}")
      end
    end
  end
end
