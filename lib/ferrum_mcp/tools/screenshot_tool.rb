# frozen_string_literal: true

require 'base64'
require 'securerandom'

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
        end

        data = with_css_selector(selector, element) do |css_selector|
          options[:selector] = css_selector if css_selector
          resize_if_needed(page.screenshot(**options), format)
        end
        image_response(Base64.strict_encode64(data), format == 'png' ? 'image/png' : 'image/jpeg')
      end

      private

      # Ferrum's screenshot(selector:) only takes CSS; map refs/xpath to a CSS
      # selector by tagging the resolved element only for this capture.
      def with_css_selector(selector, element)
        return yield(nil) unless selector

        kind, expression = resolve_selector(selector)
        return yield(expression) if kind == :css

        marker = SecureRandom.hex(16)
        previous = element.attribute('data-fmcp-shot')
        page.execute("arguments[0].setAttribute('data-fmcp-shot', arguments[1])", element, marker)
        yield %([data-fmcp-shot="#{marker}"])
      ensure
        if marker
          page.execute(<<~JS, element, previous)
            const el = arguments[0], previous = arguments[1];
            if (previous === null) el.removeAttribute('data-fmcp-shot');
            else el.setAttribute('data-fmcp-shot', previous);
          JS
        end
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
