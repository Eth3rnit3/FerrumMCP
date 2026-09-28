# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Close a specific session
    class CloseSessionTool < SessionTool
      tool_name 'close_session'
      description 'Close a specific browser session by its ID. The browser will be stopped and the session removed.'

      param :session_id, type: :string, required: true, description: 'The ID of the session to close'

      def perform(params)
        session_id = params[:session_id]
        return error_response('session_id is required') if session_id.to_s.empty?

        if session_manager.close_session(session_id)
          success_response(session_id: session_id, message: 'Session closed successfully')
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
