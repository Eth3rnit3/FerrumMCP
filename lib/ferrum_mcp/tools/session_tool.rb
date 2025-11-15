# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Base class for session management tools
    class SessionTool
      attr_reader :session_manager, :logger

      def initialize(session_manager)
        @session_manager = session_manager
        @logger = session_manager.logger
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

      def success_response(data = {})
        { success: true, data: data }
      end

      def error_response(message)
        { success: false, error: message }
      end
    end
  end
end
