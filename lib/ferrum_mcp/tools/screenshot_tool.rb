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
              enum: ['png', 'jpeg'],
              description: 'Image format (default: png)',
              default: 'png'
            }
          }
        }
      end
    
      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]
        full_page = params['full_page'] || params[:full_page] || false
        format = params['format'] || params[:format] || 'png'
    
        logger.info 'Taking screenshot'
    
        # Request binary encoding from Ferrum (by default it returns base64)
        options = { format: format, full: full_page, encoding: :binary }
    
        # Add selector to options if provided, otherwise take full page/viewport screenshot
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
