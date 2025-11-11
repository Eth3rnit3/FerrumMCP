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

      def find_element(selector, timeout: 5)
        ensure_browser_active
        deadline = Time.now + timeout

        loop do
          element = browser.at_css(selector)
          return element if element

          raise ToolError, "Element not found: #{selector}" if Time.now > deadline

          sleep 0.5
        end
      rescue Ferrum::NodeNotFoundError
        raise ToolError, "Element not found: #{selector}"
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
