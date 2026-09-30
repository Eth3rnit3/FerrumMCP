# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Result hashes shared by browser and session tools. The server turns
    # them into MCP responses.
    module Responses
      protected

      def success_response(data = {})
        { success: true, data: data }
      end

      def image_response(base64_data, mime_type = 'image/png')
        { success: true, type: 'image', data: base64_data, mime_type: mime_type }
      end

      def error_response(message)
        { success: false, error: message }
      end

      # Expected failures (ToolError, a blocked URL) are logged briefly; an
      # unexpected error also gets its class and backtrace in the log.
      def failure_response(error)
        name = self.class.tool_name
        if error.is_a?(FerrumMCP::Error)
          logger.error "#{name} failed: #{error.message}"
        else
          logger.error "#{name} failed: #{error.class}: #{error.message}"
          logger.debug error.backtrace.first(10).join("\n") if error.backtrace
        end
        error_response("#{name} failed: #{error.message}")
      end
    end
  end
end
