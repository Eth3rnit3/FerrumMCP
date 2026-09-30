# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Get information about a specific session
    class GetSessionInfoTool < SessionTool
      tool_name 'get_session_info'
      description 'Get detailed information about a specific browser session'

      param :session_id, type: :string, required: true, description: 'The ID of the session'

      def perform(params)
        session_id = params[:session_id]
        session = session_manager.get_session(session_id)
        return error_response("Session not found: #{session_id}") unless session

        success_response(session.info)
      end
    end
  end
end
