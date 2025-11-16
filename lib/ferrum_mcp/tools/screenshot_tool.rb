# frozen_string_literal: true

require 'vips'

module FerrumMCP
  module Tools
    # Tool to take screenshots
    class ScreenshotTool < BaseTool
      # Claude API has a maximum dimension of 8000 pixels per side
      MAX_DIMENSION = 8000
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

        # Resize if dimensions exceed Claude API limits
        screenshot_data = resize_if_needed(screenshot_data, format)

        # Now encode the binary data to base64 for MCP
        base64_data = Base64.strict_encode64(screenshot_data)
        mime_type = format == 'png' ? 'image/png' : 'image/jpeg'

        # Use image_response for MCP image injection
        image_response(base64_data, mime_type)
      rescue StandardError => e
        logger.error "Screenshot failed: #{e.message}"
        error_response("Failed to take screenshot: #{e.message}")
      end

      private

      # Resize image if any dimension exceeds MAX_DIMENSION
      # @param image_data [String] Binary image data
      # @param format [String] Image format ('png' or 'jpeg')
      # @return [String] Resized binary image data (or original if no resize needed)
      def resize_if_needed(image_data, format)
        image = Vips::Image.new_from_buffer(image_data, '')
        width = image.width
        height = image.height

        # Check if resize is needed
        if width <= MAX_DIMENSION && height <= MAX_DIMENSION
          logger.debug "Screenshot dimensions (#{width}x#{height}) within limits, no resize needed"
          return image_data
        end

        # Calculate scaling factor to fit within MAX_DIMENSION
        scale = [MAX_DIMENSION.to_f / width, MAX_DIMENSION.to_f / height].min
        new_width = (width * scale).to_i
        new_height = (height * scale).to_i

        logger.info "Resizing screenshot from #{width}x#{height} to #{new_width}x#{new_height}"

        # Resize image (using high quality Lanczos3 interpolation)
        resized = image.thumbnail_image(new_width, height: new_height, size: :force)

        # Return resized binary data in the correct format
        resized.write_to_buffer(".#{format}")
      rescue StandardError => e
        logger.warn "Failed to resize screenshot: #{e.message}, returning original"
        image_data
      end
    end
  end
end
