# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Get information about a specific session
    class GetSessionInfoTool < SessionTool
      def self.tool_name
        'get_session_info'
      end

      def self.description
        'Get detailed information about a specific browser session'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'The ID of the session (omit for default session)'
            }
          }
        }
      end

      def execute(params)
        session_id = params[:session_id] || params['session_id']
        session = session_manager.get_session(session_id)

        return error_response("Session not found: #{session_id}") unless session

        success_response(session.info)
      rescue StandardError => e
        logger.error "Failed to get session info: #{e.message}"
        error_response("Failed to get session info: #{e.message}")
      end
    end
  end
end
