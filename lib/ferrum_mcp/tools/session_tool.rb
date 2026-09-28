# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Base class for session management tools: they talk to the SessionManager
    # and do not need a running browser.
    class SessionTool
      extend Definition

      requires_session false

      attr_reader :session_manager, :logger

      def initialize(session_manager)
        @session_manager = session_manager
        @logger = session_manager.logger
      end

      def execute(raw_params)
        perform(self.class.normalize_params(raw_params))
      end

      def perform(_params)
        raise NotImplementedError, 'Subclasses must implement #perform'
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
