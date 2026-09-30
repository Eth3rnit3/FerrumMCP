# frozen_string_literal: true

require 'base64'

module FerrumMCP
  module Tools
    # Take screenshots
    class ScreenshotTool < BaseTool
      # Claude API has a maximum dimension of 8000 pixels per side
      MAX_DIMENSION = 8000

      tool_name 'screenshot'
      description 'Take a screenshot of the page or of a specific element (returned as an image)'

      param :selector, type: :string, description: 'Optional: selector of the element to screenshot'
      param :full_page, type: :boolean, default: false, description: 'Capture the full scrollable page (default: false)'
      param :format, type: :string, default: 'png', enum: %w[png jpeg], description: 'Image format (default: png)'

      def perform(params)
        ensure_browser_active
        selector = params[:selector]
        format = params[:format]
        logger.info 'Taking screenshot'

        options = { format: format, full: params[:full_page], encoding: :binary }
        if selector
          element = find_element(selector)
          element.scroll_into_view
          sleep 0.1 # let the element render after scrolling
          options[:selector] = css_selector_for(selector, element)
        end

        data = resize_if_needed(page.screenshot(**options), format)
        image_response(Base64.strict_encode64(data), format == 'png' ? 'image/png' : 'image/jpeg')
      end

      private

      # Ferrum's screenshot(selector:) only takes CSS; map refs/xpath to a CSS
      # selector by tagging the resolved element.
      def css_selector_for(selector, element)
        kind, expression = resolve_selector(selector)
        return expression if kind == :css

        page.execute("arguments[0].setAttribute('data-fmcp-shot', '1')", element)
        '[data-fmcp-shot="1"]'
      end

      # Resize image if any dimension exceeds MAX_DIMENSION. Needs libvips; when
      # it is not installed the original image is returned untouched.
      def resize_if_needed(image_data, format)
        return image_data unless ImageResizer.available?

        ImageResizer.fit(image_data, MAX_DIMENSION, format, logger: logger)
      rescue StandardError => e
        logger.warn "Failed to resize screenshot: #{e.message}, returning original"
        image_data
      end
    end
  end
end
