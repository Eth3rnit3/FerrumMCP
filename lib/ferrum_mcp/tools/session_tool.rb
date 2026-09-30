# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Base class for session management tools: they talk to the SessionManager
    # and do not need a running browser.
    class SessionTool
      extend Definition
      include Responses

      requires_session false

      attr_reader :session_manager, :logger

      def initialize(session_manager)
        @session_manager = session_manager
        @logger = session_manager.logger
      end

      # Any error raised by #perform becomes an error response
      def execute(raw_params)
        perform(self.class.normalize_params(raw_params))
      rescue StandardError => e
        failure_response(e)
      end

      def perform(_params)
        raise NotImplementedError, 'Subclasses must implement #perform'
      end
    end
  end
end
