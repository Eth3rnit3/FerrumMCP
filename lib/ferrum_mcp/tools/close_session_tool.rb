# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Close a specific session
    class CloseSessionTool < SessionTool
      def self.tool_name
        'close_session'
      end

      def self.description
        'Close a specific browser session by its ID. The browser will be stopped and the session will be removed.'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'The ID of the session to close'
            }
          },
          required: ['session_id']
        }
      end

      def execute(params)
        session_id = params[:session_id] || params['session_id']

        return error_response('session_id is required') unless session_id

        success = session_manager.close_session(session_id)

        if success
          success_response(
            session_id: session_id,
            message: 'Session closed successfully'
          )
        else
          error_response("Session not found: #{session_id}")
        end
      rescue StandardError => e
        logger.error "Failed to close session: #{e.message}"
        error_response("Failed to close session: #{e.message}")
      end
    end
  end
end
