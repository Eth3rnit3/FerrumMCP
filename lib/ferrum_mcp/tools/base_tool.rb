# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Base class for all MCP tools
    class BaseTool
      attr_reader :browser, :logger

      def initialize(browser_manager)
        @browser_manager = browser_manager
        @browser = browser_manager.browser
        @logger = browser_manager.logger
      end

      def execute(params)
        raise NotImplementedError, 'Subclasses must implement #execute'
      end

      def self.tool_name
        raise NotImplementedError, 'Subclasses must implement .tool_name'
      end

      def self.description
        raise NotImplementedError, 'Subclasses must implement .description'
      end

      def self.input_schema
        raise NotImplementedError, 'Subclasses must implement .input_schema'
      end

      protected

      def ensure_browser_active
        raise BrowserError, 'Browser is not active' unless @browser_manager.active?

        @browser = @browser_manager.browser
      end

      # Helper to access params consistently (supports both string and symbol keys)
      def param(params, key)
        params[key.to_s] || params[key.to_sym]
      end

      # Find element with improved timeout handling
      # Uses shorter polling intervals for better responsiveness
      def find_element(selector, timeout: 5)
        ensure_browser_active
        deadline = Time.now + timeout

        loop do
          element = browser.at_css(selector)
          return element if element

          raise ToolError, "Element not found: #{selector}" if Time.now > deadline

          # Use shorter sleep for better responsiveness (0.1s instead of 0.5s)
          sleep 0.1
        end
      rescue Ferrum::NodeNotFoundError
        raise ToolError, "Element not found: #{selector}"
      end

      # Retry logic for handling stale/moving elements
      def with_retry(retries: 3)
        attempts = 0
        begin
          attempts += 1
          yield
        rescue Ferrum::NodeMovingError => e
          raise ToolError, "Element became stale after #{retries} retries" unless attempts < retries

          logger.debug "Retry #{attempts}/#{retries} due to: #{e.class}"
          sleep 0.1
          retry
        end
      end

      # Check if element is actually visible (has dimensions and not hidden)
      def element_visible?(element)
        return false unless element

        # Check both CSS visibility and actual rendered dimensions
        script = <<~JS
          (function(el) {
            if (!el) return false;
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return rect.width > 0 &&
                   rect.height > 0 &&
                   style.visibility !== 'hidden' &&
                   style.display !== 'none';
          })(arguments[0])
        JS

        browser.evaluate(script, element)
      rescue StandardError => e
        logger.debug "Error checking element visibility: #{e.message}"
        false
      end

      def success_response(data = {})
        { success: true, data: data }
      end

      def image_response(base64_data, mime_type = 'image/png')
        { success: true, type: 'image', data: base64_data, mime_type: mime_type }
      end

      def error_response(message)
        { success: false, error: message }
      end
    end
  end
end
